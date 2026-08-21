from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.announcement import Announcement
from app.models.category import Category
from app.models.customer import Customer
from app.models.membership import Membership
from app.models.order import Order, OrderItem, OrderStatus
from app.models.platform_extra import DiscountCode, LoyaltyTransaction, Wallet, WalletTransaction
from app.models.product import Product
from app.models.restaurant import Restaurant

router = APIRouter(tags=["Platform"])


class OrderItemIn(BaseModel):
    product_id: int
    quantity: int = Field(ge=1, le=99)


class OrderCreate(BaseModel):
    restaurant_id: int
    items: list[OrderItemIn] = Field(min_length=1)
    discount_code: str | None = None
    note: str | None = None


class DiscountCreate(BaseModel):
    restaurant_id: int
    code: str = Field(min_length=2, max_length=50)
    title: str
    discount_type: str
    amount: int = Field(gt=0)
    min_purchase: int = Field(default=0, ge=0)
    max_discount: int | None = Field(default=None, ge=0)
    min_visits: int = Field(default=0, ge=0)
    min_spent: int = Field(default=0, ge=0)
    usage_limit: int | None = Field(default=None, ge=1)
    expires_at: datetime | None = None


class AnnouncementCreate(BaseModel):
    restaurant_id: int
    title: str
    body: str
    image: str | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class ProfileUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None


class OrderStatusUpdate(BaseModel):
    status: str


class WalletCredit(BaseModel):
    customer_id: int
    amount: int = Field(gt=0)
    description: str = "شارژ کیف پول"


def _customer(db: Session, user_id: int, restaurant_id: int) -> Customer:
    row = db.scalar(select(Customer).where(Customer.user_id == user_id, Customer.restaurant_id == restaurant_id))
    if row is None:
        row = Customer(user_id=user_id, restaurant_id=restaurant_id)
        db.add(row)
        db.flush()
    return row


def _membership(db: Session, user_id: int, restaurant_id: int) -> Membership:
    membership = db.scalar(select(Membership).where(Membership.user_id == user_id, Membership.restaurant_id == restaurant_id))
    if membership is None or membership.role not in {"owner", "admin", "staff"}:
        raise HTTPException(status_code=403, detail="دسترسی ندارید")
    return membership


def _admin(db: Session, user_id: int, restaurant_id: int) -> Membership:
    membership = db.scalar(select(Membership).where(Membership.user_id == user_id, Membership.restaurant_id == restaurant_id))
    if membership is None or membership.role not in {"owner", "admin"}:
        raise HTTPException(status_code=403, detail="دسترسی مدیریتی ندارید")
    return membership


def _tier(customer: Customer) -> str:
    if customer.total_spent >= 5_000_000 or customer.visit_count >= 20:
        return "platinum"
    if customer.total_spent >= 2_000_000 or customer.visit_count >= 10:
        return "gold"
    if customer.total_spent >= 500_000 or customer.visit_count >= 5:
        return "silver"
    return "bronze"


def _discount_amount(code: DiscountCode, subtotal: int) -> int:
    if subtotal < code.min_purchase:
        return 0
    value = subtotal * code.amount // 100 if code.discount_type == "percent" else code.amount
    if code.max_discount is not None:
        value = min(value, code.max_discount)
    return min(value, subtotal)


@router.get("/api/customer/restaurants")
def restaurants(db: Annotated[Session, Depends(get_db)]):
    rows = db.scalars(select(Restaurant).order_by(Restaurant.id.desc())).all()
    return [{"id": r.id, "name": r.name, "slug": r.slug, "logo": r.logo, "description": r.description} for r in rows]


@router.patch("/api/customer/profile")
def update_profile(data: ProfileUpdate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    if data.name is not None:
        current_user.name = data.name.strip()
    if data.phone is not None:
        current_user.phone = data.phone.strip()
    db.commit()
    return {"id": current_user.id, "email": current_user.email, "name": current_user.name, "phone": current_user.phone}


@router.get("/api/customer/{restaurant_id}/dashboard")
def dashboard(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    announcements = db.scalars(
        select(Announcement).where(Announcement.restaurant_id == restaurant_id, Announcement.is_active).order_by(Announcement.created_at.desc()).limit(20)
    ).all()
    discounts = db.scalars(
        select(DiscountCode).where(DiscountCode.restaurant_id == restaurant_id, DiscountCode.active).order_by(DiscountCode.id.desc())
    ).all()
    usable = [d for d in discounts if d.min_visits <= customer.visit_count and d.min_spent <= customer.total_spent and (d.expires_at is None or d.expires_at > datetime.utcnow()) and (d.usage_limit is None or d.used_count < d.usage_limit)]
    return {
        "customer": {"points": customer.points, "total_spent": customer.total_spent, "visit_count": customer.visit_count, "tier": customer.tier},
        "announcements": [{"id": a.id, "title": a.title, "body": a.body, "image": a.image, "created_at": a.created_at} for a in announcements],
        "discounts": [{"id": d.id, "code": d.code, "title": d.title, "discount_type": d.discount_type, "amount": d.amount, "min_purchase": d.min_purchase} for d in usable],
    }


@router.get("/api/customer/{restaurant_id}/discounts")
def discounts(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    rows = db.scalars(select(DiscountCode).where(DiscountCode.restaurant_id == restaurant_id, DiscountCode.active)).all()
    return [{"id": d.id, "code": d.code, "title": d.title, "discount_type": d.discount_type, "amount": d.amount, "eligible": d.min_visits <= customer.visit_count and d.min_spent <= customer.total_spent} for d in rows]


@router.post("/api/customer/orders", status_code=status.HTTP_201_CREATED)
def create_order(data: OrderCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    product_ids = [item.product_id for item in data.items]
    products = db.scalars(
        select(Product).join(Category, Product.category_id == Category.id).where(Product.id.in_(product_ids), Category.restaurant_id == data.restaurant_id)
    ).all()
    by_id = {p.id: p for p in products}
    if len(by_id) != len(set(product_ids)):
        raise HTTPException(status_code=400, detail="یک یا چند محصول متعلق به این رستوران نیست")

    subtotal = 0
    order_items: list[OrderItem] = []
    for item in data.items:
        product = by_id[item.product_id]
        if not product.available:
            raise HTTPException(status_code=409, detail=f"محصول «{product.name}» ناموجود است")
        line = product.price * item.quantity
        subtotal += line
        order_items.append(OrderItem(product_id=product.id, product_name=product.name, unit_price=product.price, quantity=item.quantity))

    customer = _customer(db, current_user.id, data.restaurant_id)
    discount = 0
    code = None
    if data.discount_code:
        code = db.scalar(select(DiscountCode).where(DiscountCode.restaurant_id == data.restaurant_id, func.lower(DiscountCode.code) == data.discount_code.lower().strip(), DiscountCode.active))
        if code is None:
            raise HTTPException(status_code=400, detail="کد تخفیف معتبر نیست")
        if code.min_visits > customer.visit_count or code.min_spent > customer.total_spent:
            raise HTTPException(status_code=403, detail="این کد تخفیف هنوز برای شما فعال نشده است")
        if subtotal < code.min_purchase:
            raise HTTPException(status_code=400, detail="حداقل مبلغ خرید رعایت نشده است")
        if code.expires_at and code.expires_at <= datetime.utcnow():
            raise HTTPException(status_code=400, detail="کد تخفیف منقضی شده است")
        if code.usage_limit is not None and code.used_count >= code.usage_limit:
            raise HTTPException(status_code=400, detail="ظرفیت استفاده از کد تخفیف تمام شده است")
        discount = _discount_amount(code, subtotal)

    order = Order(
        user_id=current_user.id,
        restaurant_id=data.restaurant_id,
        subtotal=subtotal,
        discount_amount=discount,
        total_amount=subtotal - discount,
        status=OrderStatus.PENDING.value,
        note=data.note,
    )
    db.add(order)
    db.flush()
    for item in order_items:
        item.order_id = order.id
        db.add(item)
    if code:
        code.used_count += 1
    db.commit()
    db.refresh(order)
    return {"id": order.id, "status": order.status, "subtotal": subtotal, "discount": discount, "total": order.total_amount}


@router.get("/api/customer/{restaurant_id}/orders")
def customer_orders(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    orders = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id, Order.user_id == current_user.id).order_by(Order.created_at.desc())).all()
    result = []
    for order in orders:
        items = db.scalars(select(OrderItem).where(OrderItem.order_id == order.id)).all()
        result.append({"id": order.id, "status": order.status, "subtotal": order.subtotal, "discount": order.discount_amount, "total": order.total_amount, "created_at": order.created_at, "items": [{"product_id": i.product_id, "name": i.product_name, "quantity": i.quantity, "unit_price": i.unit_price, "line_total": i.unit_price * i.quantity} for i in items]})
    return result


@router.get("/api/customer/{restaurant_id}/loyalty")
def loyalty(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    transactions = db.scalars(select(LoyaltyTransaction).where(LoyaltyTransaction.customer_id == customer.id).order_by(LoyaltyTransaction.created_at.desc()).limit(50)).all()
    return {"points": customer.points, "tier": customer.tier, "total_spent": customer.total_spent, "visit_count": customer.visit_count, "transactions": [{"points": t.points, "reason": t.reason, "created_at": t.created_at} for t in transactions]}


@router.get("/api/customer/{restaurant_id}/wallet")
def wallet(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    row = db.scalar(select(Wallet).where(Wallet.customer_id == customer.id))
    if row is None:
        row = Wallet(customer_id=customer.id, balance=0)
        db.add(row)
        db.commit()
        db.refresh(row)
    tx = db.scalars(select(WalletTransaction).where(WalletTransaction.wallet_id == row.id).order_by(WalletTransaction.created_at.desc()).limit(50)).all()
    return {"balance": row.balance, "transactions": [{"amount": t.amount, "kind": t.kind, "description": t.description, "created_at": t.created_at} for t in tx]}


@router.get("/api/customer/{restaurant_id}/recommendations")
def recommendations(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    rows = db.execute(
        select(OrderItem.product_id, func.sum(OrderItem.quantity).label("qty"))
        .join(Order, Order.id == OrderItem.order_id)
        .where(Order.restaurant_id == restaurant_id, Order.user_id == current_user.id, Order.status == OrderStatus.COMPLETED.value, OrderItem.product_id.is_not(None))
        .group_by(OrderItem.product_id)
        .order_by(func.sum(OrderItem.quantity).desc())
        .limit(6)
    ).all()
    ids = [r.product_id for r in rows]
    if ids:
        products = db.scalars(select(Product).where(Product.id.in_(ids), Product.available)).all()
        by_id = {p.id: p for p in products}
        ordered = [by_id[i] for i in ids if i in by_id]
    else:
        ordered = db.scalars(select(Product).join(Category, Product.category_id == Category.id).where(Category.restaurant_id == restaurant_id, Product.available).order_by(Product.sort_order, Product.id).limit(6)).all()
    return [{"id": p.id, "name": p.name, "description": p.description, "price": p.price, "image": p.image} for p in ordered]


@router.patch("/api/owner/{restaurant_id}/orders/{order_id}")
def update_order(restaurant_id: int, order_id: int, data: OrderStatusUpdate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _membership(db, current_user.id, restaurant_id)
    if data.status not in {s.value for s in OrderStatus}:
        raise HTTPException(status_code=400, detail="وضعیت سفارش نامعتبر است")
    order = db.scalar(select(Order).where(Order.id == order_id, Order.restaurant_id == restaurant_id))
    if order is None:
        raise HTTPException(status_code=404, detail="سفارش پیدا نشد")
    was_completed = order.status == OrderStatus.COMPLETED.value
    order.status = data.status
    if data.status == OrderStatus.COMPLETED.value and not was_completed:
        order.completed_at = datetime.utcnow()
        customer = _customer(db, order.user_id, restaurant_id)
        customer.total_spent += order.total_amount
        customer.visit_count += 1
        earned = order.total_amount // 10
        customer.points += earned
        customer.tier = _tier(customer)
        db.add(LoyaltyTransaction(restaurant_id=restaurant_id, customer_id=customer.id, points=earned, reason="تکمیل سفارش", order_id=order.id))
    db.commit()
    return {"id": order.id, "status": order.status}


@router.post("/api/owner/announcements", status_code=status.HTTP_201_CREATED)
def create_announcement(data: AnnouncementCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(db, current_user.id, data.restaurant_id)
    row = Announcement(restaurant_id=data.restaurant_id, title=data.title, body=data.body, image=data.image, starts_at=data.starts_at, ends_at=data.ends_at, is_active=True)
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "title": row.title, "body": row.body}


@router.post("/api/owner/discounts", status_code=status.HTTP_201_CREATED)
def create_discount(data: DiscountCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(db, current_user.id, data.restaurant_id)
    if data.discount_type not in {"percent", "fixed"}:
        raise HTTPException(status_code=400, detail="نوع تخفیف باید percent یا fixed باشد")
    if data.discount_type == "percent" and data.amount > 100:
        raise HTTPException(status_code=400, detail="درصد تخفیف نمی‌تواند بیشتر از ۱۰۰ باشد")
    existing = db.scalar(select(DiscountCode).where(DiscountCode.restaurant_id == data.restaurant_id, func.lower(DiscountCode.code) == data.code.lower()))
    if existing:
        raise HTTPException(status_code=409, detail="این کد تخفیف قبلاً ثبت شده است")
    row = DiscountCode(**data.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "code": row.code, "title": row.title}


@router.get("/api/owner/{restaurant_id}/orders")
def owner_orders(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _membership(db, current_user.id, restaurant_id)
    rows = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id).order_by(Order.created_at.desc()).limit(200)).all()
    return [{"id": o.id, "user_id": o.user_id, "status": o.status, "subtotal": o.subtotal, "discount": o.discount_amount, "total": o.total_amount, "created_at": o.created_at} for o in rows]


@router.post("/api/owner/{restaurant_id}/wallet/credit")
def credit_wallet(restaurant_id: int, data: WalletCredit, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(db, current_user.id, restaurant_id)
    customer = db.scalar(select(Customer).where(Customer.id == data.customer_id, Customer.restaurant_id == restaurant_id))
    if customer is None:
        raise HTTPException(status_code=404, detail="مشتری پیدا نشد")
    wallet = db.scalar(select(Wallet).where(Wallet.customer_id == customer.id))
    if wallet is None:
        wallet = Wallet(customer_id=customer.id, balance=0)
        db.add(wallet)
        db.flush()
    wallet.balance += data.amount
    db.add(WalletTransaction(wallet_id=wallet.id, amount=data.amount, kind="credit", description=data.description))
    db.commit()
    return {"customer_id": customer.id, "balance": wallet.balance}


@router.get("/api/owner/{restaurant_id}/reports")
def owner_reports(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _admin(db, current_user.id, restaurant_id)
    orders = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id)).all()
    completed = [o for o in orders if o.status == OrderStatus.COMPLETED.value]
    customers = db.scalar(select(func.count()).select_from(Customer).where(Customer.restaurant_id == restaurant_id)) or 0
    revenue = sum(o.total_amount for o in completed)
    return {"orders": len(orders), "completed_orders": len(completed), "revenue": revenue, "discount_total": sum(o.discount_amount for o in completed), "customers": customers, "average_order": revenue // len(completed) if completed else 0}

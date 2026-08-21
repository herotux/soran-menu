from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.category import Category
from app.models.membership import Membership
from app.models.platform import (
    CustomerRestaurant, DiscountCode, LoyaltyTransaction, Notification,
    Order, OrderItem, OrderStatus, Wallet, WalletTransaction,
)
from app.models.product import Product
from app.models.restaurant import Restaurant

router = APIRouter(tags=["Customer Platform"])


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


class NotificationCreate(BaseModel):
    restaurant_id: int
    title: str
    body: str


class ProfileUpdate(BaseModel):
    name: str | None = None
    phone: str | None = None


def _customer(db: Session, user_id: int, restaurant_id: int) -> CustomerRestaurant:
    row = db.scalar(select(CustomerRestaurant).where(CustomerRestaurant.user_id == user_id, CustomerRestaurant.restaurant_id == restaurant_id))
    if row is None:
        row = CustomerRestaurant(user_id=user_id, restaurant_id=restaurant_id)
        db.add(row)
        db.flush()
    return row


def _tier(row: CustomerRestaurant) -> str:
    if row.total_spent >= 5_000_000 or row.visit_count >= 20:
        return "platinum"
    if row.total_spent >= 2_000_000 or row.visit_count >= 10:
        return "gold"
    if row.total_spent >= 500_000 or row.visit_count >= 5:
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
def customer_restaurants(db: Annotated[Session, Depends(get_db)]):
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
def customer_dashboard(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    notifications = db.scalars(select(Notification).where(Notification.restaurant_id == restaurant_id, Notification.active).order_by(Notification.created_at.desc()).limit(20)).all()
    discounts = db.scalars(select(DiscountCode).where(DiscountCode.restaurant_id == restaurant_id, DiscountCode.active).order_by(DiscountCode.id.desc())).all()
    usable = [d for d in discounts if d.min_visits <= customer.visit_count and d.min_spent <= customer.total_spent and (d.expires_at is None or d.expires_at > datetime.utcnow()) and (d.usage_limit is None or d.used_count < d.usage_limit)]
    return {"customer": {"points": customer.points, "total_spent": customer.total_spent, "visit_count": customer.visit_count, "tier": customer.tier}, "notifications": [{"id": n.id, "title": n.title, "body": n.body, "created_at": n.created_at} for n in notifications], "discounts": [{"id": d.id, "code": d.code, "title": d.title, "discount_type": d.discount_type, "amount": d.amount, "min_purchase": d.min_purchase} for d in usable]}


@router.get("/api/customer/{restaurant_id}/notifications")
def customer_notifications(restaurant_id: int, db: Annotated[Session, Depends(get_db)]):
    rows = db.scalars(select(Notification).where(Notification.restaurant_id == restaurant_id, Notification.active).order_by(Notification.created_at.desc())).all()
    return [{"id": n.id, "title": n.title, "body": n.body, "created_at": n.created_at} for n in rows]


@router.get("/api/customer/{restaurant_id}/discounts")
def customer_discounts(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    rows = db.scalars(select(DiscountCode).where(DiscountCode.restaurant_id == restaurant_id, DiscountCode.active)).all()
    return [{"id": d.id, "code": d.code, "title": d.title, "discount_type": d.discount_type, "amount": d.amount, "eligible": d.min_visits <= customer.visit_count and d.min_spent <= customer.total_spent} for d in rows]


@router.post("/api/customer/orders", status_code=status.HTTP_201_CREATED)
def create_order(data: OrderCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    product_ids = [item.product_id for item in data.items]
    products = db.scalars(select(Product).join(Category, Product.category_id == Category.id).where(Product.id.in_(product_ids), Category.restaurant_id == data.restaurant_id)).all()
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
        order_items.append(OrderItem(product_id=product.id, name=product.name, unit_price=product.price, quantity=item.quantity, line_total=line))
    customer = _customer(db, current_user.id, data.restaurant_id)
    discount = 0
    code = None
    if data.discount_code:
        code = db.scalar(select(DiscountCode).where(DiscountCode.restaurant_id == data.restaurant_id, func.lower(DiscountCode.code) == data.discount_code.lower().strip(), DiscountCode.active))
        if code is None:
            raise HTTPException(status_code=400, detail="کد تخفیف معتبر نیست")
        if code.min_visits > customer.visit_count or code.min_spent > customer.total_spent:
            raise HTTPException(status_code=403, detail="این کد تخفیف هنوز برای شما فعال نشده است")
        if code.expires_at and code.expires_at <= datetime.utcnow():
            raise HTTPException(status_code=400, detail="کد تخفیف منقضی شده است")
        if code.usage_limit is not None and code.used_count >= code.usage_limit:
            raise HTTPException(status_code=400, detail="ظرفیت استفاده از کد تخفیف تمام شده است")
        discount = _discount_amount(code, subtotal)
    order = Order(restaurant_id=data.restaurant_id, customer_id=current_user.id, subtotal=subtotal, discount_amount=discount, total=subtotal - discount, note=data.note)
    order.items = order_items
    db.add(order)
    if code:
        code.used_count += 1
    db.commit()
    db.refresh(order)
    return {"id": order.id, "status": order.status, "subtotal": subtotal, "discount": discount, "total": order.total}


@router.get("/api/customer/{restaurant_id}/orders")
def customer_orders(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    orders = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id, Order.customer_id == current_user.id).order_by(Order.created_at.desc())).all()
    return [{"id": o.id, "status": o.status, "subtotal": o.subtotal, "discount": o.discount_amount, "total": o.total, "created_at": o.created_at, "items": [{"product_id": i.product_id, "name": i.name, "quantity": i.quantity, "unit_price": i.unit_price, "line_total": i.line_total} for i in o.items]} for o in orders]


@router.post("/api/customer/{restaurant_id}/orders/{order_id}/complete")
def complete_order(restaurant_id: int, order_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    order = db.scalar(select(Order).where(Order.id == order_id, Order.restaurant_id == restaurant_id, Order.customer_id == current_user.id))
    if order is None:
        raise HTTPException(status_code=404, detail="سفارش پیدا نشد")
    if order.status == OrderStatus.COMPLETED.value:
        return {"status": order.status}
    if order.status == OrderStatus.CANCELLED.value:
        raise HTTPException(status_code=409, detail="سفارش لغو شده است")
    order.status = OrderStatus.COMPLETED.value
    order.completed_at = datetime.utcnow()
    customer = _customer(db, current_user.id, restaurant_id)
    customer.total_spent += order.total
    customer.visit_count += 1
    earned = order.total // 10
    customer.points += earned
    customer.tier = _tier(customer)
    db.add(LoyaltyTransaction(restaurant_id=restaurant_id, customer_id=current_user.id, points=earned, reason="خرید", order_id=order.id))
    db.commit()
    return {"status": order.status, "earned_points": earned, "tier": customer.tier}


@router.get("/api/customer/{restaurant_id}/loyalty")
def loyalty(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = _customer(db, current_user.id, restaurant_id)
    transactions = db.scalars(select(LoyaltyTransaction).where(LoyaltyTransaction.restaurant_id == restaurant_id, LoyaltyTransaction.customer_id == current_user.id).order_by(LoyaltyTransaction.created_at.desc()).limit(50)).all()
    return {"points": customer.points, "tier": customer.tier, "total_spent": customer.total_spent, "visit_count": customer.visit_count, "transactions": [{"points": t.points, "reason": t.reason, "created_at": t.created_at} for t in transactions]}


@router.get("/api/customer/{restaurant_id}/wallet")
def wallet(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    row = db.scalar(select(Wallet).where(Wallet.user_id == current_user.id, Wallet.restaurant_id == restaurant_id))
    if row is None:
        row = Wallet(user_id=current_user.id, restaurant_id=restaurant_id)
        db.add(row)
        db.commit()
        db.refresh(row)
    tx = db.scalars(select(WalletTransaction).where(WalletTransaction.wallet_id == row.id).order_by(WalletTransaction.created_at.desc()).limit(50)).all()
    return {"balance": row.balance, "transactions": [{"amount": t.amount, "kind": t.kind, "description": t.description, "created_at": t.created_at} for t in tx]}


def _ensure_admin(restaurant_id: int, user_id: int, db: Session) -> Membership:
    membership = db.scalar(select(Membership).where(Membership.restaurant_id == restaurant_id, Membership.user_id == user_id))
    if membership is None or membership.role not in {"owner", "admin"}:
        raise HTTPException(status_code=403, detail="دسترسی مدیریتی ندارید")
    return membership


@router.post("/api/owner/notifications", status_code=201)
def create_notification(data: NotificationCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _ensure_admin(data.restaurant_id, current_user.id, db)
    row = Notification(restaurant_id=data.restaurant_id, title=data.title, body=data.body)
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "title": row.title, "body": row.body}


@router.post("/api/owner/discounts", status_code=201)
def create_discount(data: DiscountCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _ensure_admin(data.restaurant_id, current_user.id, db)
    if data.discount_type not in {"percent", "fixed"}:
        raise HTTPException(status_code=400, detail="نوع تخفیف باید percent یا fixed باشد")
    if data.discount_type == "percent" and data.amount > 100:
        raise HTTPException(status_code=400, detail="درصد تخفیف نمی‌تواند بیشتر از ۱۰۰ باشد")
    row = DiscountCode(**data.model_dump())
    db.add(row)
    db.commit()
    db.refresh(row)
    return {"id": row.id, "code": row.code, "title": row.title}


@router.get("/api/owner/{restaurant_id}/reports")
def owner_reports(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _ensure_admin(restaurant_id, current_user.id, db)
    orders = db.scalars(select(Order).where(Order.restaurant_id == restaurant_id)).all()
    completed = [o for o in orders if o.status == OrderStatus.COMPLETED.value]
    customers = db.scalar(select(func.count()).select_from(CustomerRestaurant).where(CustomerRestaurant.restaurant_id == restaurant_id)) or 0
    return {"orders": len(orders), "completed_orders": len(completed), "revenue": sum(o.total for o in completed), "discount_total": sum(o.discount_amount for o in completed), "customers": customers, "average_order": (sum(o.total for o in completed) // len(completed) if completed else 0)}

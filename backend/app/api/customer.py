from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser, require_admin
from app.database.session import get_db
from app.models.announcement import Announcement
from app.models.announcement_read import AnnouncementRead
from app.models.customer import Customer
from app.models.order import Order, OrderItem, OrderStatus
from app.models.product import Product
from app.models.restaurant import Restaurant
from app.schemas.customer import AnnouncementResponse, LoyaltySummaryResponse, OrderCreate, OrderResponse
from app.services.loyalty import ensure_default_tiers, get_loyalty_summary

router = APIRouter(prefix="/api/customer", tags=["Customer"])


def _restaurant_or_404(db: Session, restaurant_id: int) -> Restaurant:
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    return restaurant


def _ensure_customer(db: Session, user_id: int, restaurant_id: int) -> Customer:
    customer = db.scalar(select(Customer).where(Customer.user_id == user_id, Customer.restaurant_id == restaurant_id))
    if customer is None:
        customer = Customer(user_id=user_id, restaurant_id=restaurant_id)
        db.add(customer)
        ensure_default_tiers(db, restaurant_id)
        db.flush()
    return customer


@router.post("/restaurants/{restaurant_id}/join", status_code=status.HTTP_201_CREATED)
def join_restaurant(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _restaurant_or_404(db, restaurant_id)
    customer = _ensure_customer(db, current_user.id, restaurant_id)
    db.commit()
    return {"id": customer.id, "restaurant_id": restaurant_id}


@router.get("/restaurants/{restaurant_id}/announcements", response_model=list[AnnouncementResponse])
def announcements(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _restaurant_or_404(db, restaurant_id)
    now = datetime.utcnow()
    rows = list(db.execute(select(Announcement, AnnouncementRead.id.is_not(None)).outerjoin(
        AnnouncementRead,
        (AnnouncementRead.announcement_id == Announcement.id) & (AnnouncementRead.user_id == current_user.id),
    ).where(
        Announcement.restaurant_id == restaurant_id,
        Announcement.is_active.is_(True),
        (Announcement.starts_at.is_(None) | (Announcement.starts_at <= now)),
        (Announcement.ends_at.is_(None) | (Announcement.ends_at >= now)),
    ).order_by(Announcement.created_at.desc()))
    return [AnnouncementResponse.model_validate(announcement).model_copy(update={"read": read_id is not None}) for announcement, read_id in rows]


@router.post("/announcements/{announcement_id}/read")
def mark_announcement_read(announcement_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    announcement = db.get(Announcement, announcement_id)
    if announcement is None:
        raise HTTPException(status_code=404, detail="اطلاعیه پیدا نشد")
    existing = db.scalar(select(AnnouncementRead).where(AnnouncementRead.announcement_id == announcement_id, AnnouncementRead.user_id == current_user.id))
    if existing is None:
        db.add(AnnouncementRead(announcement_id=announcement_id, user_id=current_user.id))
        db.commit()
    return {"read": True}


@router.get("/restaurants/{restaurant_id}/loyalty", response_model=LoyaltySummaryResponse)
def loyalty(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _restaurant_or_404(db, restaurant_id)
    _ensure_customer(db, current_user.id, restaurant_id)
    total_spent, completed_orders, tier = get_loyalty_summary(db, current_user.id, restaurant_id)
    db.commit()
    return {"total_spent": total_spent, "completed_orders": completed_orders, "discount_percent": tier.discount_percent if tier else 0, "tier": tier}


@router.get("/restaurants/{restaurant_id}/orders", response_model=list[OrderResponse])
def my_orders(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    _restaurant_or_404(db, restaurant_id)
    return list(db.scalars(select(Order).where(Order.restaurant_id == restaurant_id, Order.user_id == current_user.id).order_by(Order.created_at.desc())))


def _create_order(db: Session, user_id: int, data: OrderCreate, allow_manual_items: bool = False) -> Order:
    _restaurant_or_404(db, data.restaurant_id)
    _ensure_customer(db, user_id, data.restaurant_id)
    product_ids = [item.product_id for item in data.items if item.product_id is not None]
    if not allow_manual_items and len(product_ids) != len(data.items):
        raise HTTPException(status_code=400, detail="هر آیتم سفارش باید محصول معتبر داشته باشد")
    products = {p.id: p for p in db.scalars(select(Product).where(Product.id.in_(product_ids)))} if product_ids else {}
    if len(products) != len(set(product_ids)):
        raise HTTPException(status_code=400, detail="یک یا چند محصول پیدا نشد")
    if any(p.category.restaurant_id != data.restaurant_id for p in products.values()):
        raise HTTPException(status_code=400, detail="محصول متعلق به این رستوران نیست")
    lines = []
    for item in data.items:
        product = products.get(item.product_id)
        price = product.price if product is not None else item.unit_price
        name = product.name if product is not None else item.product_name
        lines.append((item.product_id, name, price, item.quantity))
    subtotal = sum(price * quantity for _, _, price, quantity in lines)
    _, _, tier = get_loyalty_summary(db, user_id, data.restaurant_id)
    discount_percent = tier.discount_percent if tier else 0
    discount_amount = subtotal * discount_percent // 100
    order = Order(user_id=user_id, restaurant_id=data.restaurant_id, subtotal=subtotal, discount_amount=discount_amount, total_amount=subtotal - discount_amount, status=OrderStatus.COMPLETED.value)
    db.add(order)
    db.flush()
    for product_id, name, price, quantity in lines:
        db.add(OrderItem(order_id=order.id, product_id=product_id, product_name=name, unit_price=price, quantity=quantity))
    return order


@router.post("/orders", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_my_order(data: OrderCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    order = _create_order(db, current_user.id, data)
    db.commit()
    db.refresh(order)
    return order


@router.post("/admin/restaurants/{restaurant_id}/orders/{user_id}", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def record_purchase(restaurant_id: int, user_id: int, data: OrderCreate, _: Annotated[object, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    if data.restaurant_id != restaurant_id:
        raise HTTPException(status_code=400, detail="رستوران درخواست با مسیر یکسان نیست")
    order = _create_order(db, user_id, data, allow_manual_items=True)
    db.commit()
    db.refresh(order)
    return order


@router.get("/admin/restaurants/{restaurant_id}/customers/{user_id}/loyalty", response_model=LoyaltySummaryResponse)
def customer_loyalty(restaurant_id: int, user_id: int, _: Annotated[object, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    _restaurant_or_404(db, restaurant_id)
    _ensure_customer(db, user_id, restaurant_id)
    total_spent, completed_orders, tier = get_loyalty_summary(db, user_id, restaurant_id)
    db.commit()
    return {"total_spent": total_spent, "completed_orders": completed_orders, "discount_percent": tier.discount_percent if tier else 0, "tier": tier}

from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.platform import CustomerRestaurant, Notification, Order, OrderStatus
from app.models.restaurant import Restaurant

router = APIRouter(tags=["Customer Compatibility"])


@router.get("/api/public/restaurants")
def public_restaurants(db: Annotated[Session, Depends(get_db)]):
    rows = db.scalars(select(Restaurant).order_by(Restaurant.id.desc())).all()
    return [{"id": r.id, "name": r.name, "slug": r.slug, "logo": r.logo, "description": r.description} for r in rows]


@router.get("/api/customer/restaurants/{restaurant_id}/announcements")
def announcements(restaurant_id: int, db: Annotated[Session, Depends(get_db)]):
    rows = db.scalars(select(Notification).where(Notification.restaurant_id == restaurant_id, Notification.active).order_by(Notification.created_at.desc())).all()
    return [{"id": n.id, "title": n.title, "body": n.body, "created_at": n.created_at} for n in rows]


@router.get("/api/customer/restaurants/{restaurant_id}/loyalty")
def legacy_loyalty(restaurant_id: int, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    customer = db.scalar(select(CustomerRestaurant).where(CustomerRestaurant.restaurant_id == restaurant_id, CustomerRestaurant.user_id == current_user.id))
    if customer is None:
        return {"tier": {"name": "برنزی"}, "discount_percent": 0, "total_spent": 0, "completed_orders": 0, "points": 0}
    discount = {"bronze": 0, "silver": 5, "gold": 10, "platinum": 15}.get(customer.tier, 0)
    completed = db.scalar(select(Order).where(Order.restaurant_id == restaurant_id, Order.customer_id == current_user.id, Order.status == OrderStatus.COMPLETED.value).count()) if False else customer.visit_count
    names = {"bronze": "برنزی", "silver": "نقره‌ای", "gold": "طلایی", "platinum": "پلاتینیوم"}
    return {"tier": {"name": names.get(customer.tier, "برنزی")}, "discount_percent": discount, "total_spent": customer.total_spent, "completed_orders": completed, "points": customer.points}

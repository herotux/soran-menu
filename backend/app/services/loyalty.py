from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.customer import LoyaltyTier
from app.models.order import Order, OrderStatus


def ensure_default_tiers(db: Session, restaurant_id: int) -> None:
    exists = db.scalar(select(LoyaltyTier.id).where(LoyaltyTier.restaurant_id == restaurant_id).limit(1))
    if exists is not None:
        return
    db.add_all([
        LoyaltyTier(restaurant_id=restaurant_id, name="برنزی", min_spend=0, discount_percent=0, sort_order=0),
        LoyaltyTier(restaurant_id=restaurant_id, name="نقره‌ای", min_spend=5_000_000, discount_percent=5, sort_order=1),
        LoyaltyTier(restaurant_id=restaurant_id, name="طلایی", min_spend=10_000_000, discount_percent=10, sort_order=2),
        LoyaltyTier(restaurant_id=restaurant_id, name="VIP", min_spend=20_000_000, discount_percent=15, sort_order=3),
    ])
    db.flush()


def get_loyalty_summary(db: Session, user_id: int, restaurant_id: int):
    total_spent = db.scalar(
        select(func.coalesce(func.sum(Order.total_amount), 0)).where(
            Order.user_id == user_id,
            Order.restaurant_id == restaurant_id,
            Order.status == OrderStatus.COMPLETED.value,
        )
    ) or 0
    completed_orders = db.scalar(
        select(func.count(Order.id)).where(
            Order.user_id == user_id,
            Order.restaurant_id == restaurant_id,
            Order.status == OrderStatus.COMPLETED.value,
        )
    ) or 0
    tier = db.scalar(
        select(LoyaltyTier)
        .where(
            LoyaltyTier.restaurant_id == restaurant_id,
            LoyaltyTier.min_spend <= total_spent,
        )
        .order_by(LoyaltyTier.min_spend.desc())
    )
    return total_spent, completed_orders, tier

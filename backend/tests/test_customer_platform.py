from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.database.session import Base
from app.models.customer import LoyaltyTier
from app.models.restaurant import Restaurant
from app.models.user import User
from app.models.order import Order, OrderStatus
from app.services.loyalty import ensure_default_tiers, get_loyalty_summary
from app.schemas.customer import OrderCreate, OrderItemCreate


def make_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return engine


def test_default_loyalty_tiers_are_created_once():
    engine = make_db()
    with Session(engine) as db:
        restaurant = Restaurant(name="Test", slug="test")
        db.add(restaurant)
        db.flush()
        ensure_default_tiers(db, restaurant.id)
        ensure_default_tiers(db, restaurant.id)
        db.commit()
        tiers = db.query(LoyaltyTier).filter_by(restaurant_id=restaurant.id).all()
        assert len(tiers) == 4
        assert [t.discount_percent for t in tiers] == [0, 5, 10, 15]


def test_loyalty_uses_completed_orders_only():
    engine = make_db()
    with Session(engine) as db:
        user = User(email="customer@example.com", password_hash="x")
        restaurant = Restaurant(name="Test", slug="test")
        db.add_all([user, restaurant])
        db.flush()
        ensure_default_tiers(db, restaurant.id)
        db.add_all([
            Order(user_id=user.id, restaurant_id=restaurant.id, subtotal=6_000_000, discount_amount=0, total_amount=6_000_000, status=OrderStatus.COMPLETED.value),
            Order(user_id=user.id, restaurant_id=restaurant.id, subtotal=20_000_000, discount_amount=0, total_amount=20_000_000, status=OrderStatus.CANCELLED.value),
        ])
        db.commit()
        total, count, tier = get_loyalty_summary(db, user.id, restaurant.id)
        assert total == 6_000_000
        assert count == 1
        assert tier.discount_percent == 5


def test_order_request_rejects_empty_items():
    try:
        OrderCreate(restaurant_id=1, items=[])
    except Exception:
        return
    raise AssertionError("orders must contain at least one item")


def test_order_item_requires_positive_quantity():
    try:
        OrderItemCreate(product_name="test", unit_price=100, quantity=0)
    except Exception:
        return
    raise AssertionError("quantity must be positive")

from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from app.database.session import Base
from app.models.customer import Customer
from app.models.platform_extra import DiscountCode


def make_db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    return engine


def test_customer_numeric_defaults_are_applied_on_insert():
    engine = make_db()
    with Session(engine) as db:
        customer = Customer(user_id=1, restaurant_id=1)
        db.add(customer)
        db.flush()
        assert customer.points == 0
        assert customer.total_spent == 0
        assert customer.visit_count == 0
        assert customer.tier == "bronze"


def test_discount_numeric_defaults_are_applied_on_insert():
    engine = make_db()
    with Session(engine) as db:
        discount = DiscountCode(
            restaurant_id=1,
            code="TEST",
            title="Test",
            discount_type="percent",
            amount=10,
        )
        db.add(discount)
        db.flush()
        assert discount.min_purchase == 0
        assert discount.min_visits == 0
        assert discount.min_spent == 0
        assert discount.used_count == 0
        assert discount.active is True

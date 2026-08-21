from app.api.platform import _discount_amount, _tier
from app.models.customer import Customer
from app.models.order import OrderStatus
from app.models.platform_extra import DiscountCode


def test_customer_tiers_progress_by_visits():
    customer = Customer(user_id=1, restaurant_id=1)
    assert _tier(customer) == "bronze"
    customer.visit_count = 5
    assert _tier(customer) == "silver"
    customer.visit_count = 10
    assert _tier(customer) == "gold"
    customer.visit_count = 20
    assert _tier(customer) == "platinum"


def test_percent_discount_respects_maximum():
    code = DiscountCode(restaurant_id=1, code="SAVE20", title="۲۰ درصد", discount_type="percent", amount=20, max_discount=500)
    assert _discount_amount(code, 1000) == 200
    assert _discount_amount(code, 10000) == 500


def test_fixed_discount_never_exceeds_subtotal():
    code = DiscountCode(restaurant_id=1, code="SAVE500", title="۵۰۰", discount_type="fixed", amount=500)
    assert _discount_amount(code, 300) == 300
    assert _discount_amount(code, 1000) == 500


def test_order_status_contract():
    assert OrderStatus.PENDING.value == "pending"
    assert OrderStatus.CONFIRMED.value == "confirmed"
    assert OrderStatus.COMPLETED.value == "completed"
    assert OrderStatus.CANCELLED.value == "cancelled"

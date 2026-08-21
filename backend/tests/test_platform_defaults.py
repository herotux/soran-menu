from app.models import Customer, DiscountCode


def test_customer_total_spent_defaults_to_zero():
    customer = Customer()
    assert customer.total_spent == 0


def test_discount_min_purchase_defaults_to_zero():
    discount = DiscountCode(code="TEST", discount_type="percent", discount_value=10)
    assert discount.min_purchase == 0

from app.api.restaurants import make_slug
from app.schemas.menu import CategoryCreate, ProductCreate
from app.schemas.restaurant import RestaurantCreate


def test_slug_supports_persian_names():
    slug = make_slug("خانه سیب‌زمینی (سوران)")
    assert slug.startswith("خانه-سیب-زمینی-سوران-")
    assert len(slug.rsplit("-", 1)[-1]) == 6


def test_restaurant_create_rejects_short_names():
    try:
        RestaurantCreate(name="x")
    except Exception:
        return
    raise AssertionError("short restaurant names must be rejected")


def test_product_price_cannot_be_negative():
    try:
        ProductCreate(name="test", price=-1)
    except Exception:
        return
    raise AssertionError("negative prices must be rejected")


def test_category_defaults():
    category = CategoryCreate(name="برگر")
    assert category.sort_order == 0
    assert category.image is None

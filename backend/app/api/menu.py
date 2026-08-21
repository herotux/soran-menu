from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.category import Category
from app.models.product import Product
from app.models.restaurant import Restaurant
from app.schemas.menu import MenuCategoryResponse, MenuProductResponse, PublicMenuResponse
from app.schemas.restaurant import RestaurantResponse

router = APIRouter(prefix="/api/public", tags=["Public Menu"])


@router.get("/restaurants", response_model=list[RestaurantResponse])
def list_public_restaurants(db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(select(Restaurant).order_by(Restaurant.name)))


@router.get("/restaurants/{slug}/menu", response_model=PublicMenuResponse)
def get_public_menu(slug: str, db: Annotated[Session, Depends(get_db)]):
    restaurant = db.scalar(select(Restaurant).where(Restaurant.slug == slug))
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    categories = db.scalars(select(Category).where(Category.restaurant_id == restaurant.id).order_by(Category.sort_order, Category.id)).all()
    result_categories = []
    for category in categories:
        products = db.scalars(select(Product).where(Product.category_id == category.id, Product.available.is_(True)).order_by(Product.sort_order, Product.id)).all()
        result_categories.append(MenuCategoryResponse(
            id=category.id, restaurant_id=category.restaurant_id, external_id=category.external_id,
            name=category.name, image=category.image, sort_order=category.sort_order,
            items=[MenuProductResponse.model_validate(product) for product in products],
        ))
    return PublicMenuResponse(restaurant=restaurant, categories=result_categories)

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import require_admin, get_restaurant_membership
from app.database.session import get_db
from app.models.category import Category
from app.models.membership import Membership
from app.models.product import Product
from app.schemas.menu import ProductCreate, ProductResponse, ProductUpdate

router = APIRouter(prefix="/api/restaurants/{restaurant_id}", tags=["Products"])


def get_category(db: Session, restaurant_id: int, category_id: int) -> Category:
    category = db.scalar(select(Category).where(Category.id == category_id, Category.restaurant_id == restaurant_id))
    if category is None:
        raise HTTPException(status_code=404, detail="دسته‌بندی پیدا نشد")
    return category


@router.get("/categories/{category_id}/products", response_model=list[ProductResponse])
def list_products(
    restaurant_id: int,
    category_id: int,
    membership: Annotated[Membership, Depends(get_restaurant_membership)],
    db: Annotated[Session, Depends(get_db)],
):
    get_category(db, restaurant_id, category_id)
    return list(db.scalars(select(Product).where(Product.category_id == category_id).order_by(Product.sort_order, Product.id)).all())


@router.post("/categories/{category_id}/products", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(
    restaurant_id: int,
    category_id: int,
    data: ProductCreate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    get_category(db, restaurant_id, category_id)
    product = Product(category_id=category_id, **data.model_dump())
    db.add(product)
    db.commit()
    db.refresh(product)
    return product


@router.patch("/categories/{category_id}/products/{product_id}", response_model=ProductResponse)
def update_product(
    restaurant_id: int,
    category_id: int,
    product_id: int,
    data: ProductUpdate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    get_category(db, restaurant_id, category_id)
    product = db.scalar(select(Product).where(Product.id == product_id, Product.category_id == category_id))
    if product is None:
        raise HTTPException(status_code=404, detail="محصول پیدا نشد")
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(product, key, value)
    db.commit()
    db.refresh(product)
    return product


@router.delete("/categories/{category_id}/products/{product_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_product(
    restaurant_id: int,
    category_id: int,
    product_id: int,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    get_category(db, restaurant_id, category_id)
    product = db.scalar(select(Product).where(Product.id == product_id, Product.category_id == category_id))
    if product is None:
        raise HTTPException(status_code=404, detail="محصول پیدا نشد")
    db.delete(product)
    db.commit()

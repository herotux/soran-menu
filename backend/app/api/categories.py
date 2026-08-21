from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_restaurant_membership, require_admin
from app.database.session import get_db
from app.models.category import Category
from app.models.membership import Membership
from app.schemas.menu import CategoryCreate, CategoryResponse, CategoryUpdate

router = APIRouter(prefix="/api/restaurants/{restaurant_id}/categories", tags=["Categories"])


@router.get("", response_model=list[CategoryResponse])
def list_categories(
    restaurant_id: int,
    membership: Annotated[Membership, Depends(get_restaurant_membership)],
    db: Annotated[Session, Depends(get_db)],
):
    return list(db.scalars(select(Category).where(Category.restaurant_id == restaurant_id).order_by(Category.sort_order, Category.id)).all())


@router.post("", response_model=CategoryResponse, status_code=status.HTTP_201_CREATED)
def create_category(
    restaurant_id: int,
    data: CategoryCreate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    category = Category(restaurant_id=restaurant_id, **data.model_dump())
    db.add(category)
    db.commit()
    db.refresh(category)
    return category


@router.patch("/{category_id}", response_model=CategoryResponse)
def update_category(
    restaurant_id: int,
    category_id: int,
    data: CategoryUpdate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    category = db.scalar(select(Category).where(Category.id == category_id, Category.restaurant_id == restaurant_id))
    if category is None:
        raise HTTPException(status_code=404, detail="دسته‌بندی پیدا نشد")
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(category, key, value)
    db.commit()
    db.refresh(category)
    return category


@router.delete("/{category_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_category(
    restaurant_id: int,
    category_id: int,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    category = db.scalar(select(Category).where(Category.id == category_id, Category.restaurant_id == restaurant_id))
    if category is None:
        raise HTTPException(status_code=404, detail="دسته‌بندی پیدا نشد")
    db.delete(category)
    db.commit()

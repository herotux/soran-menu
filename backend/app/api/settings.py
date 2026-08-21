from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import require_admin
from app.database.session import get_db
from app.models.membership import Membership
from app.models.restaurant import Restaurant
from app.schemas.restaurant import RestaurantResponse, RestaurantUpdate

router = APIRouter(prefix="/api/restaurants/{restaurant_id}/settings", tags=["Settings"])


@router.get("", response_model=RestaurantResponse)
def get_settings(
    restaurant_id: int,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    return restaurant


@router.patch("", response_model=RestaurantResponse)
def update_settings(
    restaurant_id: int,
    data: RestaurantUpdate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(restaurant, key, value)
    db.commit()
    db.refresh(restaurant)
    return restaurant

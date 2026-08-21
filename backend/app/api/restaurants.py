import re
import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser, get_restaurant_membership, require_admin, require_owner
from app.database.session import get_db
from app.models.membership import Membership, MembershipRole
from app.models.restaurant import Restaurant
from app.schemas.restaurant import RestaurantCreate, RestaurantResponse, RestaurantUpdate

router = APIRouter(prefix="/api/restaurants", tags=["Restaurants"])


def make_slug(name: str) -> str:
    value = re.sub(r"[^a-z0-9\u0600-\u06ff]+", "-", name.strip().lower()).strip("-") or "restaurant"
    return f"{value}-{secrets.token_hex(3)}"


@router.post("", response_model=RestaurantResponse, status_code=status.HTTP_201_CREATED)
def create_restaurant(data: RestaurantCreate, current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    restaurant = Restaurant(name=data.name.strip(), slug=make_slug(data.name))
    db.add(restaurant)
    db.flush()
    db.add(Membership(user_id=current_user.id, restaurant_id=restaurant.id, role=MembershipRole.OWNER.value))
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.get("", response_model=list[RestaurantResponse])
def list_my_restaurants(current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(
        select(Restaurant).join(Membership, Membership.restaurant_id == Restaurant.id)
        .where(Membership.user_id == current_user.id).order_by(Restaurant.id.desc())
    ).all())


@router.get("/{restaurant_id}", response_model=RestaurantResponse)
def get_restaurant(
    restaurant_id: int,
    membership: Annotated[Membership, Depends(get_restaurant_membership)],
    db: Annotated[Session, Depends(get_db)],
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    return restaurant


@router.patch("/{restaurant_id}", response_model=RestaurantResponse)
def update_restaurant(
    restaurant_id: int,
    data: RestaurantUpdate,
    membership: Annotated[Membership, Depends(require_admin)],
    db: Annotated[Session, Depends(get_db)],
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    for key, value in data.model_dump(exclude_unset=True).items():
        if key == "name":
            value = value.strip()
        setattr(restaurant, key, value)
    db.commit()
    db.refresh(restaurant)
    return restaurant


@router.delete("/{restaurant_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_restaurant(
    restaurant_id: int,
    membership: Annotated[Membership, Depends(require_owner)],
    db: Annotated[Session, Depends(get_db)],
):
    restaurant = db.get(Restaurant, restaurant_id)
    if restaurant is None:
        raise HTTPException(status_code=404, detail="رستوران پیدا نشد")
    db.delete(restaurant)
    db.commit()

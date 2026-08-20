import re
import secrets

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.membership import Membership, MembershipRole
from app.models.restaurant import Restaurant
from app.schemas.restaurant import (
    RestaurantCreate,
    RestaurantResponse,
)


router = APIRouter(
    prefix="/api/restaurants",
    tags=["Restaurants"],
)


def make_slug(name: str) -> str:
    value = name.strip().lower()

    value = re.sub(
        r"[^a-z0-9\u0600-\u06ff]+",
        "-",
        value,
    )

    value = value.strip("-")

    if not value:
        value = "restaurant"

    return f"{value}-{secrets.token_hex(3)}"


@router.post(
    "",
    response_model=RestaurantResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_restaurant(
    data: RestaurantCreate,
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    name = data.name.strip()

    if len(name) < 2:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="نام رستوران معتبر نیست",
        )

    restaurant = Restaurant(
        name=name,
        slug=make_slug(name),
    )

    db.add(restaurant)
    db.flush()

    membership = Membership(
        user_id=current_user.id,
        restaurant_id=restaurant.id,
        role=MembershipRole.OWNER.value,
    )

    db.add(membership)
    db.commit()
    db.refresh(restaurant)

    return restaurant


@router.get(
    "",
    response_model=list[RestaurantResponse],
)
def list_my_restaurants(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    restaurants = db.scalars(
        select(Restaurant)
        .join(
            Membership,
            Membership.restaurant_id == Restaurant.id,
        )
        .where(
            Membership.user_id == current_user.id,
        )
        .order_by(Restaurant.id.desc())
    ).all()

    return list(restaurants)

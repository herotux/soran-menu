from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models.membership import Membership
from app.models.restaurant import Restaurant
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse, UserResponse
from app.schemas.restaurant import RestaurantResponse
from app.services.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, db: Annotated[Session, Depends(get_db)]):
    email = data.email.lower().strip()
    if db.scalar(select(User).where(User.email == email)) is not None:
        raise HTTPException(status_code=409, detail="این ایمیل قبلاً ثبت شده است")
    if len(data.password) < 8:
        raise HTTPException(status_code=400, detail="رمز عبور باید حداقل ۸ کاراکتر باشد")
    user = User(email=email, password_hash=hash_password(data.password), name=data.name, phone=data.phone)
    db.add(user)
    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id), user=user)


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Annotated[Session, Depends(get_db)]):
    user = db.scalar(select(User).where(User.email == data.email.lower().strip()))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="ایمیل یا رمز عبور اشتباه است", headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=403, detail="حساب کاربری غیرفعال است")
    return TokenResponse(access_token=create_access_token(user.id), user=user)


@router.get("/me", response_model=UserResponse)
def me(current_user: Annotated[User, Depends(get_current_user)]):
    return current_user


@router.get("/me/restaurants", response_model=list[RestaurantResponse])
def my_restaurants(current_user: Annotated[User, Depends(get_current_user)], db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(select(Restaurant).join(Membership, Membership.restaurant_id == Restaurant.id).where(Membership.user_id == current_user.id).order_by(Restaurant.id.desc())).all())

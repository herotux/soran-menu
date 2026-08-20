from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import get_current_user
from app.database.session import get_db
from app.models.user import User
from app.schemas.auth import (
    LoginRequest,
    RegisterRequest,
    TokenResponse,
    UserResponse,
)
from app.services.security import (
    create_access_token,
    hash_password,
    verify_password,
)


router = APIRouter(
    prefix="/api/auth",
    tags=["Authentication"],
)


@router.post(
    "/register",
    response_model=TokenResponse,
    status_code=status.HTTP_201_CREATED,
)
def register(
    data: RegisterRequest,
    db: Annotated[Session, Depends(get_db)],
):
    email = data.email.lower().strip()

    existing_user = db.scalar(
        select(User).where(User.email == email),
    )

    if existing_user is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="این ایمیل قبلاً ثبت شده است",
        )

    if len(data.password) < 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="رمز عبور باید حداقل ۸ کاراکتر باشد",
        )

    user = User(
        email=email,
        password_hash=hash_password(data.password),
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id)

    return TokenResponse(
        access_token=token,
        user=user,
    )


@router.post(
    "/login",
    response_model=TokenResponse,
)
def login(
    data: LoginRequest,
    db: Annotated[Session, Depends(get_db)],
):
    email = data.email.lower().strip()

    user = db.scalar(
        select(User).where(User.email == email),
    )

    if user is None or not verify_password(
        data.password,
        user.password_hash,
    ):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="ایمیل یا رمز عبور اشتباه است",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="حساب کاربری غیرفعال است",
        )

    token = create_access_token(user.id)

    return TokenResponse(
        access_token=token,
        user=user,
    )


@router.get(
    "/me",
    response_model=UserResponse,
)
def me(
    current_user: Annotated[
        User,
        Depends(get_current_user),
    ],
):
    return current_user

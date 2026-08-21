import re
import secrets
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.membership import Membership
from app.models.restaurant import Restaurant
from app.models.tenant import Tenant, TenantMembership, TenantRole
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenResponse, UserResponse
from app.schemas.restaurant import RestaurantResponse
from app.services.security import create_access_token, hash_password, verify_password

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


def make_tenant_slug(name: str) -> str:
    value = re.sub(r"[^a-z0-9\u0600-\u06ff]+", "-", name.strip().lower()).strip("-") or "tenant"
    return f"{value}-{secrets.token_hex(3)}"


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(data: RegisterRequest, db: Annotated[Session, Depends(get_db)]):
    email = data.email.lower().strip()
    if db.scalar(select(User).where(User.email == email)) is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="این ایمیل قبلاً ثبت شده است")
    if len(data.password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="رمز عبور باید حداقل ۸ کاراکتر باشد")

    user = User(email=email, password_hash=hash_password(data.password), name=data.name, phone=data.phone)
    db.add(user)
    db.flush()

    tenant_name = (data.name or email.split("@", 1)[0]).strip() or "سازمان جدید"
    tenant = Tenant(name=tenant_name, slug=make_tenant_slug(tenant_name))
    db.add(tenant)
    db.flush()
    db.add(TenantMembership(tenant_id=tenant.id, user_id=user.id, role=TenantRole.OWNER.value))

    db.commit()
    db.refresh(user)
    return TokenResponse(access_token=create_access_token(user.id), user=user)


@router.post("/login", response_model=TokenResponse)
def login(data: LoginRequest, db: Annotated[Session, Depends(get_db)]):
    user = db.scalar(select(User).where(User.email == data.email.lower().strip()))
    if user is None or not verify_password(data.password, user.password_hash):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="ایمیل یا رمز عبور اشتباه است", headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="حساب کاربری غیرفعال است")
    return TokenResponse(access_token=create_access_token(user.id), user=user)


@router.get("/me", response_model=UserResponse)
def me(current_user: CurrentUser):
    return current_user


@router.get("/me/restaurants", response_model=list[RestaurantResponse])
def my_restaurants(current_user: CurrentUser, db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(
        select(Restaurant)
        .join(Membership, Membership.restaurant_id == Restaurant.id)
        .where(Membership.user_id == current_user.id)
        .order_by(Restaurant.name)
    ))

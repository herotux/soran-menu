from typing import Annotated

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.membership import Membership, MembershipRole
from app.models.user import User
from app.services.security import decode_access_token


security = HTTPBearer()


def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials,
        Depends(security),
    ],
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> User:
    try:
        user_id = decode_access_token(
            credentials.credentials,
        )
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="توکن نامعتبر است",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.get(User, user_id)

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="کاربر پیدا نشد",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="حساب کاربری غیرفعال است",
        )

    return user


CurrentUser = Annotated[
    User,
    Depends(get_current_user),
]


def get_restaurant_membership(
    restaurant_id: int,
    current_user: CurrentUser,
    db: Annotated[
        Session,
        Depends(get_db),
    ],
) -> Membership:
    membership = db.scalar(
        select(Membership).where(
            Membership.user_id == current_user.id,
            Membership.restaurant_id == restaurant_id,
        )
    )

    if membership is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="شما به این رستوران دسترسی ندارید",
        )

    return membership


def require_owner(
    membership: Annotated[
        Membership,
        Depends(get_restaurant_membership),
    ],
) -> Membership:
    if membership.role != MembershipRole.OWNER.value:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="دسترسی فقط برای مالک رستوران است",
        )

    return membership


def require_admin(
    membership: Annotated[
        Membership,
        Depends(get_restaurant_membership),
    ],
) -> Membership:
    allowed_roles = {
        MembershipRole.OWNER.value,
        MembershipRole.ADMIN.value,
    }

    if membership.role not in allowed_roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="دسترسی مدیریتی ندارید",
        )

    return membership


def require_staff(
    membership: Annotated[
        Membership,
        Depends(get_restaurant_membership),
    ],
) -> Membership:
    return membership

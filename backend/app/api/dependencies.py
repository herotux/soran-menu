from typing import Annotated

from fastapi import Depends, Header, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.database.session import get_db
from app.models.membership import Membership, MembershipRole
from app.models.tenant import Tenant, TenantMembership
from app.models.user import User
from app.services.security import decode_access_token


security = HTTPBearer()


def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
    db: Annotated[Session, Depends(get_db)],
) -> User:
    try:
        user_id = decode_access_token(credentials.credentials)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="توکن نامعتبر است", headers={"WWW-Authenticate": "Bearer"})

    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="کاربر پیدا نشد", headers={"WWW-Authenticate": "Bearer"})
    if not user.is_active:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="حساب کاربری غیرفعال است")
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def get_current_tenant(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
    tenant_id: Annotated[int | None, Header(alias="X-Tenant-ID")] = None,
) -> Tenant:
    memberships = list(db.scalars(
        select(TenantMembership).where(TenantMembership.user_id == current_user.id)
    ).all())

    if not memberships:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="حساب شما هنوز به هیچ سازمانی متصل نیست")

    if tenant_id is None:
        if len(memberships) > 1:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="X-Tenant-ID برای انتخاب سازمان الزامی است")
        tenant_id = memberships[0].tenant_id

    membership = next((item for item in memberships if item.tenant_id == tenant_id), None)
    if membership is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="به این سازمان دسترسی ندارید")

    tenant = db.get(Tenant, tenant_id)
    if tenant is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="سازمان پیدا نشد")
    return tenant


CurrentTenant = Annotated[Tenant, Depends(get_current_tenant)]


def get_restaurant_membership(
    restaurant_id: int,
    current_user: CurrentUser,
    current_tenant: CurrentTenant,
    db: Annotated[Session, Depends(get_db)],
) -> Membership:
    membership = db.scalar(
        select(Membership)
        .join(Membership.restaurant)
        .where(
            Membership.user_id == current_user.id,
            Membership.restaurant_id == restaurant_id,
        )
    )

    if membership is None:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="شما به این رستوران دسترسی ندارید")
    if membership.restaurant.tenant_id != current_tenant.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="این رستوران متعلق به سازمان انتخاب‌شده نیست")

    return membership


def require_owner(membership: Annotated[Membership, Depends(get_restaurant_membership)]) -> Membership:
    if membership.role != MembershipRole.OWNER.value:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی فقط برای مالک رستوران است")
    return membership


def require_admin(membership: Annotated[Membership, Depends(get_restaurant_membership)]) -> Membership:
    allowed_roles = {MembershipRole.OWNER.value, MembershipRole.ADMIN.value}
    if membership.role not in allowed_roles:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="دسترسی مدیریتی ندارید")
    return membership


def require_staff(membership: Annotated[Membership, Depends(get_restaurant_membership)]) -> Membership:
    return membership

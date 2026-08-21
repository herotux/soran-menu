from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import CurrentUser
from app.database.session import get_db
from app.models.tenant import Tenant, TenantMembership
from app.schemas.tenant import TenantResponse

router = APIRouter(prefix="/api/tenants", tags=["Tenants"])


@router.get("", response_model=list[TenantResponse])
def list_my_tenants(
    current_user: CurrentUser,
    db: Annotated[Session, Depends(get_db)],
):
    return list(db.scalars(
        select(Tenant)
        .join(TenantMembership, TenantMembership.tenant_id == Tenant.id)
        .where(TenantMembership.user_id == current_user.id)
        .order_by(Tenant.name)
    ).all())

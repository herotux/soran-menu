from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.dependencies import require_admin
from app.database.session import get_db
from app.models.announcement import Announcement
from app.models.customer import LoyaltyTier
from app.models.membership import Membership
from app.schemas.announcement import (
    AnnouncementCreate,
    AnnouncementUpdate,
    LoyaltyTierCreate,
    LoyaltyTierResponse,
    LoyaltyTierUpdate,
)

router = APIRouter(prefix="/api/restaurants/{restaurant_id}", tags=["Customer Engagement"])


@router.get("/announcements/admin", response_model=list)
def list_admin_announcements(restaurant_id: int, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(select(Announcement).where(Announcement.restaurant_id == restaurant_id).order_by(Announcement.created_at.desc())))


@router.post("/announcements", status_code=status.HTTP_201_CREATED)
def create_announcement(restaurant_id: int, data: AnnouncementCreate, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    announcement = Announcement(restaurant_id=restaurant_id, **data.model_dump())
    db.add(announcement)
    db.commit()
    db.refresh(announcement)
    return announcement


@router.patch("/announcements/{announcement_id}")
def update_announcement(restaurant_id: int, announcement_id: int, data: AnnouncementUpdate, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    announcement = db.scalar(select(Announcement).where(Announcement.id == announcement_id, Announcement.restaurant_id == restaurant_id))
    if announcement is None:
        raise HTTPException(status_code=404, detail="اطلاعیه پیدا نشد")
    for key, value in data.model_dump(exclude_unset=True).items():
        setattr(announcement, key, value)
    db.commit()
    db.refresh(announcement)
    return announcement


@router.delete("/announcements/{announcement_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_announcement(restaurant_id: int, announcement_id: int, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    announcement = db.scalar(select(Announcement).where(Announcement.id == announcement_id, Announcement.restaurant_id == restaurant_id))
    if announcement is None:
        raise HTTPException(status_code=404, detail="اطلاعیه پیدا نشد")
    db.delete(announcement)
    db.commit()


@router.get("/loyalty-tiers", response_model=list[LoyaltyTierResponse])
def list_loyalty_tiers(restaurant_id: int, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    return list(db.scalars(select(LoyaltyTier).where(LoyaltyTier.restaurant_id == restaurant_id).order_by(LoyaltyTier.min_spend.asc())))


@router.post("/loyalty-tiers", response_model=LoyaltyTierResponse, status_code=status.HTTP_201_CREATED)
def create_loyalty_tier(restaurant_id: int, data: LoyaltyTierCreate, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    tier = LoyaltyTier(restaurant_id=restaurant_id, **data.model_dump())
    db.add(tier)
    db.commit()
    db.refresh(tier)
    return tier


@router.patch("/loyalty-tiers/{tier_id}", response_model=LoyaltyTierResponse)
def update_loyalty_tier(restaurant_id: int, tier_id: int, data: LoyaltyTierUpdate, _: Annotated[Membership, Depends(require_admin)], db: Annotated[Session, Depends(get_db)]):
    tier = db.scalar(select(LoyaltyTier).where(LoyaltyTier.id == tier_id, LoyaltyTier.restaurant_id == restaurant_id))
    if tier is None:
        raise HTTPException(status_code=404, detail="سطح وفاداری پیدا نشد")
    for key, value in data.model_dump().items():
        setattr(tier, key, value)
    db.commit()
    db.refresh(tier)
    return tier

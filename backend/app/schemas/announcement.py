from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class AnnouncementCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    body: str = Field(min_length=1)
    image: str | None = None
    is_active: bool = True
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class AnnouncementUpdate(BaseModel):
    title: str | None = Field(default=None, max_length=255)
    body: str | None = None
    image: str | None = None
    is_active: bool | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None


class LoyaltyTierCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    min_spend: int = Field(ge=0)
    discount_percent: int = Field(ge=0, le=100)
    sort_order: int = Field(ge=0, default=0)


class LoyaltyTierUpdate(LoyaltyTierCreate):
    pass


class LoyaltyTierResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    restaurant_id: int
    name: str
    min_spend: int
    discount_percent: int
    sort_order: int

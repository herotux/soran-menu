from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class CustomerRegisterRequest(BaseModel):
    restaurant_id: int


class LoyaltyTierResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    name: str
    min_spend: int
    discount_percent: int


class LoyaltySummaryResponse(BaseModel):
    total_spent: int
    completed_orders: int
    discount_percent: int
    tier: LoyaltyTierResponse | None


class AnnouncementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    title: str
    body: str
    image: str | None
    starts_at: datetime | None
    ends_at: datetime | None
    created_at: datetime
    read: bool = False


class OrderItemCreate(BaseModel):
    product_id: int | None = None
    product_name: str = Field(min_length=1, max_length=255)
    unit_price: int = Field(ge=0)
    quantity: int = Field(ge=1, le=100)


class OrderCreate(BaseModel):
    restaurant_id: int
    items: list[OrderItemCreate] = Field(min_length=1)


class OrderResponse(BaseModel):
    id: int
    restaurant_id: int
    subtotal: int
    discount_amount: int
    total_amount: int
    status: str
    created_at: datetime

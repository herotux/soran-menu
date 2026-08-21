from pydantic import BaseModel, ConfigDict, Field


class RestaurantCreate(BaseModel):
    name: str = Field(min_length=2, max_length=255)


class RestaurantUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = None
    logo: str | None = None
    phone: str | None = None
    mobile: str | None = None
    address: str | None = None
    instagram: str | None = None
    telegram: str | None = None
    theme_background: str | None = None
    theme_accent: str | None = None
    theme_secondary: str | None = None


class RestaurantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str
    description: str | None = None
    logo: str | None = None
    phone: str | None = None
    mobile: str | None = None
    address: str | None = None
    instagram: str | None = None
    telegram: str | None = None
    theme_background: str | None = None
    theme_accent: str | None = None
    theme_secondary: str | None = None

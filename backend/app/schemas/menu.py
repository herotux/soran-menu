from pydantic import BaseModel, ConfigDict, Field

from app.schemas.restaurant import RestaurantResponse


class CategoryCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    external_id: str | None = None
    image: str | None = None
    sort_order: int = 0


class CategoryUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    external_id: str | None = None
    image: str | None = None
    sort_order: int | None = None


class CategoryResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    restaurant_id: int
    external_id: str | None
    name: str
    image: str | None
    sort_order: int


class ProductCreate(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    description: str = ""
    price: int = Field(ge=0)
    old_price: int | None = Field(default=None, ge=0)
    external_id: str | None = None
    image: str | None = None
    available: bool = True
    sort_order: int = 0


class ProductUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = None
    price: int | None = Field(default=None, ge=0)
    old_price: int | None = Field(default=None, ge=0)
    external_id: str | None = None
    image: str | None = None
    available: bool | None = None
    sort_order: int | None = None


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    category_id: int
    external_id: str | None
    name: str
    description: str
    price: int
    old_price: int | None
    image: str | None
    available: bool
    sort_order: int


class MenuProductResponse(ProductResponse):
    pass


class MenuCategoryResponse(CategoryResponse):
    items: list[MenuProductResponse] = []


class PublicMenuResponse(BaseModel):
    restaurant: RestaurantResponse
    categories: list[MenuCategoryResponse]

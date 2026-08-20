from pydantic import BaseModel, ConfigDict


class RestaurantCreate(BaseModel):
    name: str


class RestaurantResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    slug: str

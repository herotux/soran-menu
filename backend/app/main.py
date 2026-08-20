from fastapi import FastAPI

from app.api.auth import router as auth_router
from app.api.categories import router as categories_router
from app.api.menu import router as menu_router
from app.api.products import router as products_router
from app.api.restaurants import router as restaurants_router
from app.api.settings import router as settings_router
from app.api.uploads import router as uploads_router
from app.config import settings


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
)


app.include_router(auth_router)
app.include_router(categories_router)
app.include_router(products_router)
app.include_router(restaurants_router)
app.include_router(menu_router)
app.include_router(settings_router)
app.include_router(uploads_router)


@app.get("/health", tags=["System"])
def health():
    return {
        "status": "ok",
        "environment": settings.app_env,
    }

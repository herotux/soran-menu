from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.auth import router as auth_router
from app.api.categories import router as categories_router
from app.api.customer_compat import router as customer_compat_router
from app.api.menu import router as menu_router
from app.api.owner_platform import router as owner_platform_router
from app.api.products import router as products_router
from app.api.recommendations import router as recommendations_router
from app.api.restaurants import router as restaurants_router
from app.api.settings import router as settings_router
from app.api.uploads import router as uploads_router
from app.api.platform import router as platform_router
from app.config import settings

app = FastAPI(title=settings.app_name, version="0.3.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[origin.strip() for origin in settings.cors_origins.split(",") if origin.strip()],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Path("/app/uploads").mkdir(parents=True, exist_ok=True)
app.mount("/uploads", StaticFiles(directory="/app/uploads"), name="uploads")

app.include_router(auth_router)
app.include_router(categories_router)
app.include_router(products_router)
app.include_router(restaurants_router)
app.include_router(menu_router)
app.include_router(settings_router)
app.include_router(uploads_router)
app.include_router(platform_router)
app.include_router(owner_platform_router)
app.include_router(recommendations_router)
app.include_router(customer_compat_router)


@app.get("/health", tags=["System"])
def health():
    return {"status": "ok", "environment": settings.app_env, "version": app.version}

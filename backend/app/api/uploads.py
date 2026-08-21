from pathlib import Path
from uuid import uuid4
from typing import Annotated

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status

from app.api.dependencies import CurrentUser

router = APIRouter(prefix="/api/uploads", tags=["Uploads"])
UPLOAD_DIR = Path("/app/uploads")
ALLOWED_TYPES = {"image/jpeg": ".jpg", "image/png": ".png", "image/webp": ".webp"}
MAX_SIZE = 5 * 1024 * 1024


@router.post("/image")
async def upload_image(current_user: CurrentUser, file: UploadFile = File(...)):
    suffix = ALLOWED_TYPES.get(file.content_type or "")
    if suffix is None:
        raise HTTPException(status_code=415, detail="فرمت تصویر پشتیبانی نمی‌شود")
    data = await file.read(MAX_SIZE + 1)
    if len(data) > MAX_SIZE:
        raise HTTPException(status_code=413, detail="حجم تصویر بیش از ۵ مگابایت است")
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}{suffix}"
    path = UPLOAD_DIR / filename
    path.write_bytes(data)
    return {"url": f"/uploads/{filename}", "filename": filename}

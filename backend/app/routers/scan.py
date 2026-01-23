from fastapi import APIRouter, UploadFile
from app.services.yolo_service import detect_product

router = APIRouter()

@router.post("/scan/image")
async def scan_image(file: UploadFile):
    image = await file.read()
    return detect_product(image)

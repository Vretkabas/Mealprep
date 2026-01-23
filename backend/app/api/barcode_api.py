from fastapi import APIRouter, HTTPException
from app.services.openfoodfacts_service import get_product_by_barcode

router = APIRouter(prefix="/food", tags=["Food"])


@router.get("/barcode/{barcode}")
def lookup_barcode(barcode: str):
    product = get_product_by_barcode(barcode)

    if not product:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    return product


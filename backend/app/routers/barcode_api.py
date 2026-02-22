from fastapi import APIRouter, HTTPException, Depends
from app.services.openfoodfacts_service import get_product_by_barcode
from app.auth import get_current_user

router = APIRouter(prefix="/food", tags=["Food"])


@router.get("/barcode/{barcode}")
def lookup_barcode(
    barcode: str,
    user_id: str = Depends(get_current_user),
):
    product = get_product_by_barcode(
        barcode=barcode,
        user_id=user_id,
    )

    if not product:
        raise HTTPException(
            status_code=404,
            detail="Product not found"
        )

    return product

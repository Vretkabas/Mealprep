from fastapi import APIRouter, HTTPException, Query
from typing import Optional
from .openfoodfacts_service import get_product_by_barcode

router = APIRouter()


@router.get("/food/barcode/{barcode}")
async def get_product(
    barcode: str,
    user_id: Optional[str] = Query(None, description="User ID voor scan logging"),
    log_scan: bool = Query(True, description="Log deze scan naar database")
):
    try:
        print(f"Fetching product for barcode: {barcode}")
        if log_scan:
            print(f"Scan logging enabled for user: {user_id or 'test-user'}")
        
        # Haal product op (logt automatisch als log_scan=True)
        product = get_product_by_barcode(
            barcode, 
            user_id=user_id, 
            log_scan=log_scan
        )
        
        if not product:
            raise HTTPException(status_code=404, detail="Product niet gevonden")
        
        return product
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in get_product endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))
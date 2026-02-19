from fastapi import APIRouter, HTTPException, Query, depends
from typing import Optional
from ..services.openfoodfacts_service import get_product_by_barcode
from auth import get_current_user

router = APIRouter()


@router.get("/food/barcode/{barcode}")
async def get_product(
    barcode: str,
    user_id: str = Depends(get_current_user),
    log_scan: bool = Query(True, description="Log deze scan naar database"),
    allow_duplicates: bool = Query(False, description="Sta dubbele scans toe binnen time window"),
    duplicate_window_minutes: int = Query(1440, description="Time window voor duplicate detection in minuten (24u)")
):
    # kijkt of er een product is met deze barcode in de database (SQLite) en logt de scan naar Supabase als log_scan True is
    try:
        print(f"Fetching product for barcode: {barcode}")
        
        if log_scan:
            dup_msg = "allowed" if allow_duplicates else f"prevented (window: {duplicate_window_minutes}min)"
            print(f"Scan logging enabled - duplicates {dup_msg} - user: {user_id or 'test-user'}")
        
        # Haal product op met duplicate prevention
        product = get_product_by_barcode(
            barcode, 
            user_id=user_id, 
            log_scan=log_scan,
            allow_duplicate_scans=allow_duplicates,
            duplicate_window_minutes=duplicate_window_minutes
        )
        
        if not product:
            raise HTTPException(status_code=404, detail="Product niet gevonden")
        
        # Log het resultaat
        if log_scan:
            if product.get("scan_logged"):
                print(f"Scan logged to database")
            else:
                status = product.get("scan_status", "unknown")
                print(f"⏭Scan NOT logged - reason: {status}")
        
        return product
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error in get_product endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/food/barcode/{barcode}/force-log")
async def get_product_force_log(
    barcode: str,
    user_id: Optional[str] = Query(None, description="User ID voor scan logging")
):
    return await get_product(
        barcode=barcode,
        user_id=user_id,
        log_scan=True,
        allow_duplicates=True
    )
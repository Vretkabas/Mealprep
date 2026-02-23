from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from app.services.suggestion_service import generate_promotion_suggestions
from app.auth import get_current_user

router = APIRouter()


# ── Schemas ──────────────────────────────────────────────────────────────────

class SuggestionRequest(BaseModel):
    store_name: str                        # bv. "Colruyt" of "Delhaize"
    scanned_products: List[str]            # bv. ["Kipfilet", "Witte rijst"]


class SuggestionItem(BaseModel):
    product_name: str
    reason: str
    discount_label: Optional[str] = None
    promo_price: Optional[float] = None
    category: Optional[str] = None
    is_healthy: Optional[bool] = None


class SuggestionResponse(BaseModel):
    suggestions: List[SuggestionItem]
    meal_tip: str


# ── Endpoint ──────────────────────────────────────────────────────────────────

@router.post("/suggestions/promotions", response_model=SuggestionResponse)
async def get_promotion_suggestions(
    request: SuggestionRequest,
    user_id: str = Depends(get_current_user), 
):
    if not request.scanned_products:
        raise HTTPException(status_code=400, detail="Geen producten meegegeven.")

    try:
        result = await generate_promotion_suggestions(
            scanned_products=request.scanned_products,
            user_id=user_id,
            store_name=request.store_name,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

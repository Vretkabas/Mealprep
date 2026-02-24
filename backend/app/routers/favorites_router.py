from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from app.services.favorites_service import (
    get_favorites as fetch_favorites,
    add_favorite as create_favorite,
    remove_favorite as delete_favorite,
    check_favorite as is_favorite,
)
from app.auth import get_current_user
from uuid import UUID

router = APIRouter()


class FavoriteProduct(BaseModel):
    favorite_id: UUID
    product_id: UUID
    
    barcode: Optional[str] = None
    product_name: str
    brand: Optional[str] = None
    energy_kcal: Optional[float] = None
    proteins_g: Optional[float] = None
    carbohydrates_g: Optional[float] = None
    fat_g: Optional[float] = None
    nutriscore_grade: Optional[str] = None
    image_url: Optional[str] = None
    created_at: Optional[str] = None

    model_config = {"from_attributes": True}


class AddFavoriteRequest(BaseModel):
    product_id: str


@router.get("/favorites", response_model=List[FavoriteProduct])
async def get_favorites(user_id: str = Depends(get_current_user)):
    """Haal alle favoriete producten op van de ingelogde gebruiker."""
    return await fetch_favorites(user_id)


@router.post("/favorites")
async def add_favorite(
    request: AddFavoriteRequest,
    user_id: str = Depends(get_current_user),
):
    """Voeg een product toe aan favorieten."""
    try:
        await create_favorite(user_id, request.product_id)
        return {"message": "Toegevoegd aan favorieten."}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/favorites/{product_id}")
async def remove_favorite(
    product_id: str,
    user_id: str = Depends(get_current_user),
):
    """Verwijder een product uit favorieten."""
    try:
        await delete_favorite(user_id, product_id)
        return {"message": "Verwijderd uit favorieten."}
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/favorites/{product_id}/check")
async def check_favorite(
    product_id: str,
    user_id: str = Depends(get_current_user),
):
    """Controleer of een product in favorieten staat."""
    result = await is_favorite(user_id, product_id)
    return {"is_favorite": result}
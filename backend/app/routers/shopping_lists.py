from fastapi import APIRouter, HTTPException
from app.supabase_client import supabase
from app.services.shopping_list_service import add_item_by_barcode, create_list, get_list_items_with_names

router = APIRouter()

@router.post("/shopping-lists", status_code=201)
def create_shopping_list(data: dict):

    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase not initialized")

    user_id = data.get("user_id")
    list_name = data.get("list_name")

    if not user_id or not list_name:
        raise HTTPException(status_code=400, detail="Missing fields")

    return create_list(supabase, user_id, list_name)

@router.get("/shopping-lists/{list_id}/items")
def get_list_items(list_id: str):
    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase not initialized")

    return get_list_items_with_names(supabase, list_id)

@router.post("/shopping-lists/{list_id}/items/by-barcode", status_code=201)
def add_item_barcode(list_id: str, data: dict):
    """
    Voeg een product toe aan een lijst op basis van barcode
    """
    if supabase is None:
        raise HTTPException(status_code=500, detail="Supabase not initialized")

    barcode = data.get("barcode")
    quantity = data.get("quantity", 1)

    if not barcode:
        raise HTTPException(status_code=400, detail="Missing barcode")

    try:
        result = add_item_by_barcode(supabase, list_id, barcode, quantity)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    


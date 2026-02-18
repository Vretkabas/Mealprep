from app.auth import get_current_user
from fastapi import APIRouter, HTTPException, Depends
from app.supabase_client import supabase
from app.services.shopping_list_service import add_item_by_barcode, get_list_items_with_names

router = APIRouter()

@router.post("/shopping-lists", status_code=201)
def create_shopping_list(data: dict, user_id: str = Depends(get_current_user)):
    list_name = data.get("list_name")

    if not list_name:
        raise HTTPException(status_code=400, detail="Missing list_name")

    result = supabase.table("shopping_lists").insert({
        "user_id": user_id,
        "list_name": list_name,
        "status": "active"
    }).execute()

    return result.data[0]


#Items ophalen
@router.get("/shopping-lists/{list_id}/items")
def get_list_items(list_id: str, user_id: str = Depends(get_current_user)):
    return get_list_items_with_names(supabase, list_id)


#Item toevoegen via barcode
@router.post("/shopping-lists/{list_id}/items/by-barcode", status_code=201)
def add_item_barcode(list_id: str, data: dict, user_id: str = Depends(get_current_user)):
    barcode = data.get("barcode")
    quantity = data.get("quantity", 1)

    if not barcode:
        raise HTTPException(status_code=400, detail="Missing barcode")

    return add_item_by_barcode(supabase, list_id, barcode, quantity)
    

@router.get("/shopping-lists")
def get_user_lists(user_id: str = Depends(get_current_user)):
    result = supabase.table("shopping_lists") \
        .select("*") \
        .eq("user_id", user_id) \
        .execute()

    return result.data or []

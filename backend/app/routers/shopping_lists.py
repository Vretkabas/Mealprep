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

    result = add_item_by_barcode(supabase, list_id, barcode, quantity)
    
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    
    return result

@router.get("/shopping-lists")
def get_user_lists(user_id: str = Depends(get_current_user)):
    result = supabase.table("shopping_lists") \
        .select("*") \
        .eq("user_id", user_id) \
        .execute()

    return result.data or []


@router.patch("/shopping-lists/items/{item_id}")
def update_item(item_id: str, data: dict, user_id: str = Depends(get_current_user)):

    update_data = {}

    if "is_checked" in data:
        update_data["is_checked"] = data["is_checked"]

    if "quantity" in data:
        if data["quantity"] < 1:
            raise HTTPException(status_code=400, detail="Quantity must be greater then 0")
        update_data["quantity"] = data["quantity"]

    if not update_data:
        raise HTTPException(status_code=400, detail="Nothing to update")

    result = supabase.table("shopping_list_items") \
        .update(update_data) \
        .eq("item_id", item_id) \
        .execute()
    return result.data[0]

@router.delete("/shopping-lists/items/{item_id}", status_code=204)
def delete_item(item_id: str, user_id: str = Depends(get_current_user)):
    supabase.table("shopping_list_items") \
        .delete() \
        .eq("item_id", item_id) \
        .execute()


@router.delete("/shopping-lists/{list_id}", status_code=204)
def delete_shopping_list(list_id: str, user_id: str = Depends(get_current_user)):

    # Controleer of lijst van ingelogde gebruiker is
    existing = supabase.table("shopping_lists") \
        .select("list_id") \
        .eq("list_id", list_id) \
        .eq("user_id", user_id) \
        .execute()

    if not existing.data:
        raise HTTPException(status_code=404, detail="Lijst niet gevonden")

    # lijst verwijderen
    supabase.table("shopping_lists") \
        .delete() \
        .eq("list_id", list_id) \
        .execute()

    return
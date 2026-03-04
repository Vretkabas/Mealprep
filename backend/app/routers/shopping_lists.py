from app.auth import get_current_user
from fastapi import APIRouter, HTTPException, Depends
from app.supabase_client import supabase
from app.services.shopping_list_service import add_item_by_barcode, get_list_items_with_names, recalculate_list_totals

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


@router.post("/shopping-lists/items/{item_id}/update")
def update_item(item_id: str, data: dict, user_id: str = Depends(get_current_user)):

    # Haal list_id op vóór de update (nodig voor herberekening)
    item_row = supabase.table("shopping_list_items") \
        .select("list_id, quantity") \
        .eq("item_id", item_id) \
        .single() \
        .execute()
    if not item_row.data:
        raise HTTPException(status_code=404, detail="Item niet gevonden")
    list_id = item_row.data["list_id"]

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

    # Herbereken list totals alleen als quantity is gewijzigd (niet bij is_checked)
    if "quantity" in data:
        recalculate_list_totals(supabase, list_id)

    return result.data[0]

@router.delete("/shopping-lists/items/{item_id}", status_code=204)
def delete_item(item_id: str, user_id: str = Depends(get_current_user)):
    # Haal list_id op vóór het verwijderen
    item_row = supabase.table("shopping_list_items") \
        .select("list_id") \
        .eq("item_id", item_id) \
        .single() \
        .execute()
    list_id = item_row.data["list_id"] if item_row.data else None

    supabase.table("shopping_list_items") \
        .delete() \
        .eq("item_id", item_id) \
        .execute()

    if list_id:
        recalculate_list_totals(supabase, list_id)


@router.delete("/shopping-lists/{list_id}", status_code=204)
def delete_shopping_list(list_id: str, user_id: str = Depends(get_current_user)):

    existing = supabase.table("shopping_lists") \
        .select("list_id") \
        .eq("list_id", list_id) \
        .eq("user_id", user_id) \
        .execute()

    if not existing.data:
        raise HTTPException(status_code=404, detail="Lijst niet gevonden")

    supabase.table("shopping_lists") \
        .delete() \
        .eq("list_id", list_id) \
        .execute()

    return
from http.client import HTTPException
from supabase import Client
from app.services.product_service import find_product_by_barcode
import uuid

def create_list(supabase: Client, user_id: str, list_name: str):
    result = supabase.table("shopping_lists").insert({
        "user_id": user_id,
        "list_name": list_name,
        "status": "active"
    }).execute()

    return result.data[0]

def get_product_id_by_barcode(supabase: Client, barcode: str) -> str | None:
    """Zoek een product_id op basis van de barcode"""
    result = supabase.table("products").select("product_id").eq("barcode", barcode).limit(1).execute()
    print(f"[DEBUG] Barcode lookup '{barcode}': {result.data}")
    if result.data and len(result.data) > 0:
        return result.data[0]["product_id"]
    return None


def get_or_create_product(supabase: Client, barcode: str) -> str | None:
    match = find_product_by_barcode(barcode)
    if not match:
        return None

    existing = get_product_id_by_barcode(supabase, match.barcode)
    if existing:
        return existing

    result = supabase.table("products").upsert({
        "product_id": str(uuid.uuid4()),
        "barcode": match.barcode,
        "product_name": match.product_name or f"Onbekend ({match.barcode})",
        "brand": match.brands,
        "energy_kcal": match.energy_kcal_100g,
        "proteins_g": match.proteins_100g,
        "carbohydrates_g": match.carbohydrates_100g,
        "fat_g": match.fat_100g,
        "sugars_g": match.sugars_100g,
    }, on_conflict="barcode").execute()

    if result.data:
        return result.data[0]["product_id"]
    return None


def add_item_by_barcode(supabase: Client, list_id: str, barcode: str, quantity: int = 1):
    product_id = get_or_create_product(supabase, barcode)
    if not product_id:
        return {"error": f"Product met barcode {barcode} niet gevonden in OpenFoodFacts"}

    existing = supabase.table("shopping_list_items") \
        .select("item_id, quantity") \
        .eq("list_id", list_id) \
        .eq("product_id", product_id) \
        .execute()

    if existing.data:
        item = existing.data[0]
        new_quantity = item["quantity"] + quantity
        supabase.table("shopping_list_items") \
            .update({"quantity": new_quantity}) \
            .eq("item_id", item["item_id"]) \
            .execute()
        return {"updated": True, "item_id": item["item_id"]}
    else:
        insert_result = supabase.table("shopping_list_items").insert({
            "list_id": list_id,
            "product_id": product_id,
            "quantity": quantity,
            "is_checked": False
        }).execute()
        return {"created": True, "item_id": insert_result.data[0]["item_id"]}


def get_list_items_with_names(supabase: Client, list_id: str):
    result = supabase.table("shopping_list_items") \
        .select("""
            item_id,
            product_id,
            quantity,
            is_checked,
            products!inner(product_name, barcode)
        """) \
        .eq("list_id", list_id) \
        .execute()

    if not result.data:
        return []

    # Supabase nested select geeft dicts zoals {'products': {'product_name': ...}}
    items_with_names = []
    for row in result.data:
        items_with_names.append({
            "item_id": row["item_id"],
            "product_id": row["product_id"],
            "product_name": row["products"]["product_name"],
            "barcode": row["products"]["barcode"],
            "quantity": row["quantity"],
            "is_checked": row["is_checked"]
        })

    return items_with_names
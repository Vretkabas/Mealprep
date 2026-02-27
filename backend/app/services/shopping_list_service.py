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
            has_promo,
            promo_id,
            price_per_unit,
            products!inner(product_name, barcode, price, brand, image_url),
            promotions(promo_id, discount_percentage, original_price, promo_price, deal_quantity, is_meerdere_artikels)
        """) \
        .eq("list_id", list_id) \
        .execute()

    if not result.data:
        return []

    items_with_names = []
    for row in result.data:
        promo = row.get("promotions") or {}
        product = row.get("products") or {}

        # Bereken effectieve prijs per stuk
        price_per_unit = row.get("price_per_unit")
        original_price = promo.get("original_price") or (product.get("price") if product else None)
        promo_price = promo.get("promo_price")

        if price_per_unit is None and promo_price:
            price_per_unit = promo_price
        elif price_per_unit is None and original_price:
            price_per_unit = original_price

        quantity = row["quantity"]
        line_total = round(price_per_unit * quantity, 2) if price_per_unit else None

        # Besparing per stuk
        savings_per_unit = None
        if row.get("has_promo") and original_price and promo_price:
            savings_per_unit = round(original_price - promo_price, 2)

        items_with_names.append({
            "item_id": row["item_id"],
            "product_id": row["product_id"],
            "product_name": product.get("product_name", "Onbekend"),
            "barcode": product.get("barcode"),
            "brand": product.get("brand"),
            "quantity": quantity,
            "is_checked": row["is_checked"],
            "has_promo": row.get("has_promo", False),
            "price_per_unit": price_per_unit,
            "original_price": original_price,
            "promo_price": promo_price,
            "line_total": line_total,
            "savings_per_unit": savings_per_unit,
            "discount_label": promo.get("discount_percentage"),
            "deal_quantity": promo.get("deal_quantity"),
        })

    return items_with_names
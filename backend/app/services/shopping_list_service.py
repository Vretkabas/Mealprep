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
        # Update image_url als die nog ontbreekt
        if match.image_url:
            supabase.table("products").update({
                "image_url": match.image_url,
            }).eq("product_id", existing).is_("image_url", "null").execute()
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
        "image_url": match.image_url,
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

        original_price = promo.get("original_price") or (product.get("price") if product else None)
        promo_price = promo.get("promo_price")
        deal_quantity = promo.get("deal_quantity")
        is_meerdere_artikels = promo.get("is_meerdere_artikels", False)

        quantity = row["quantity"]
        has_promo = row.get("has_promo", False)

        # Bereken line_total, price_per_unit en savings correct op basis van promotietype
        line_total = None
        savings_per_unit = None

        if has_promo and original_price and promo_price:
            if is_meerdere_artikels and deal_quantity and deal_quantity > 1:
                # "2e aan -X% vanaf Y st" type:
                # Elke complete groep van `deal_quantity` items kost allemaal `promo_price` per stuk.
                # Items buiten een complete groep kosten `original_price`.
                complete_groups = quantity // deal_quantity
                remaining = quantity % deal_quantity
                line_total = round(
                    complete_groups * deal_quantity * promo_price
                    + remaining * original_price,
                    2
                )
                # price_per_unit: promo_price als alle items in complete groepen zitten, anders origineel
                price_per_unit = promo_price if (complete_groups > 0 and remaining == 0) else original_price
                # Totale besparing gedeeld door quantity zodat frontend (savings_per_unit * quantity) klopt
                total_savings = complete_groups * deal_quantity * (original_price - promo_price)
                savings_per_unit = round(total_savings / quantity, 4) if quantity > 0 else 0
            else:
                # Gewone korting: elke unit aan promo prijs
                price_per_unit = promo_price
                line_total = round(promo_price * quantity, 2)
                savings_per_unit = round(original_price - promo_price, 2)
        else:
            price_per_unit = original_price
            if original_price:
                line_total = round(original_price * quantity, 2)

        items_with_names.append({
            "item_id": row["item_id"],
            "product_id": row["product_id"],
            "product_name": product.get("product_name", "Onbekend"),
            "barcode": product.get("barcode"),
            "brand": product.get("brand"),
            "image_url": product.get("image_url"),
            "quantity": quantity,
            "is_checked": row["is_checked"],
            "has_promo": has_promo,
            "price_per_unit": price_per_unit,
            "original_price": original_price,
            "promo_price": promo_price,
            "line_total": line_total,
            "savings_per_unit": savings_per_unit,
            "discount_label": promo.get("discount_percentage"),
            "deal_quantity": deal_quantity,
        })

    return items_with_names


def recalculate_list_totals(supabase: Client, list_id: str):
    """
    Herbereken estimated_total_price en estimated_savings voor een shopping list
    en sla ze op in de shopping_lists tabel.
    Houdt rekening met 'meerdere artikels' promoties (bv. 2e aan -25%).
    """
    items = get_list_items_with_names(supabase, list_id)

    total_price = 0.0
    total_savings = 0.0

    for item in items:
        line_total = item.get("line_total") or 0.0
        savings_per_unit = item.get("savings_per_unit") or 0.0
        quantity = item.get("quantity", 1)

        total_price += line_total
        # savings_per_unit is al berekend als total_savings / quantity (zie get_list_items_with_names)
        total_savings += savings_per_unit * quantity

    supabase.table("shopping_lists").update({
        "estimated_total_price": round(total_price, 2),
        "estimated_savings": round(total_savings, 2),
    }).eq("list_id", list_id).execute()
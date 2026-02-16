from supabase import Client

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
    if result.data and len(result.data) > 0:
        return result.data[0]["product_id"]
    return None

def add_item_by_barcode(supabase: Client, list_id: str, barcode: str, quantity: int = 1):
    # Haal product_id op via barcode
    product_id = get_product_id_by_barcode(supabase, barcode)
    if not product_id:
        return {"error": f"Product met barcode {barcode} niet gevonden"}

    # Check of item al bestaat
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

        return {"updated": True}

    else:
        supabase.table("shopping_list_items").insert({
            "list_id": list_id,
            "product_id": product_id,
            "quantity": quantity,
            "is_checked": False
        }).execute()

        return {"created": True}

def get_list_items_with_names(supabase: Client, list_id: str):
    """
    Haal alle items van een lijst op, inclusief productnamen.
    """
    result = supabase.table("shopping_list_items") \
        .select("""
            item_id,
            product_id,
            quantity,
            is_checked,
            products!inner(product_name)
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
            "quantity": row["quantity"],
            "is_checked": row["is_checked"]
        })

    return items_with_names

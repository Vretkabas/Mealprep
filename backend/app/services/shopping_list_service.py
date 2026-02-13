from supabase import Client
from typing import Optional

def create_list(supabase: Client, user_id: str, list_name: str):
    result = supabase.table("shopping_lists").insert({
        "user_id": user_id,
        "list_name": list_name,
        "status": "active"
    }).execute()

    return result.data[0]


def add_item_to_list(supabase: Client, list_id: str, product_id: str, quantity: int = 1):
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

from fastapi import APIRouter, HTTPException
from app.supabase_client import supabase
from app.services.shopping_list_service import create_list

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

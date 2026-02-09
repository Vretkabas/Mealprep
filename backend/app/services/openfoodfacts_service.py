import sqlite3
from pathlib import Path
from datetime import datetime
from typing import Optional
import os
from supabase import create_client, Client

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "openfoodfacts.db"

# Supabase client initialiseren
try:
    SUPABASE_URL = os.getenv("SUPABASE_URL")
    SUPABASE_KEY = os.getenv("SUPABASE_KEY")
    
    if SUPABASE_URL and SUPABASE_KEY:
        supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
        print("Supabase client initialized successfully")
    else:
        supabase = None
        print("Warning: Supabase credentials not found. Scan logging disabled.")
except Exception as e:
    supabase = None
    print(f"Warning: Failed to initialize Supabase: {e}")


def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def log_scan_to_supabase(
    barcode: str,
    user_id: Optional[str] = None,
    scan_mode: str = "barcode"
) -> bool:
    # Log een scan naar Supabase
    if not supabase:
        print("Warning: Supabase not initialized, skipping scan log")
        return False
    
    try:
        # Gebruik test user ID (tijdelijk omdat gebruikers nog niet aangemaakt worden)
        user_id = user_id or "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        
        scan_data = {
            "user_id": user_id,
            "barcode": barcode,
            "scan_mode": scan_mode,
            "product_id": None,
            "scanned_at": datetime.now().isoformat(),
        }
        
        result = supabase.table("scanned_items").insert(scan_data).execute()
        print(f"Scan logged successfully for barcode: {barcode}, user: {user_id}")
        return True
        
    except Exception as e:
        print(f"Error logging scan to Supabase: {e}")
        return False


def get_product_by_barcode(
    barcode: str,
    user_id: Optional[str] = None,
    log_scan: bool = True
) -> dict | None:
    # Het product via de barcode ophalen uit de lokale db
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
 
        cursor.execute(
            """
            SELECT
                barcode,
                product_name,
                brands,
                energy_kcal_100g,
                proteins_100g,
                carbohydrates_100g,
                fat_100g,
                sugars_100g,
                salt_100g
            FROM products
            WHERE barcode = ?
            LIMIT 1
            """,
            (barcode,),
        )
 
        row = cursor.fetchone()
        conn.close()
 
        if not row:
            return None

        product = {
            "barcode": row["barcode"],
            "name": row["product_name"],
            "brands": row["brands"],
            "nutriments": {
                "energy_kcal": row["energy_kcal_100g"],
                "proteins": row["proteins_100g"],
                "carbohydrates": row["carbohydrates_100g"],
                "fat": row["fat_100g"],
                "sugars": row["sugars_100g"],
                "salt": row["salt_100g"],
            },
        }
        
        # Log de scan naar Supabase in achtergrond, falen blokkeert product niet
        if log_scan:
            log_scan_to_supabase(barcode, user_id)
        
        return product

    except Exception as e:
        print(f"Fout bij ophalen product uit DB: {e}")
        return None
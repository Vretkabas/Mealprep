import sqlite3
from pathlib import Path
from datetime import datetime, timedelta
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


def check_recent_scan(
    barcode: str,
    user_id: str,
    time_window_minutes: int = 1440  # kijkt of er binnen de laatste 24 uur al een scan is geweest
) -> bool:
    if not supabase:
        return False
    
    try:
        # Bereken de tijd vanaf wanneer we kijken
        time_threshold = datetime.now() - timedelta(minutes=time_window_minutes)
        
        # Check of er een scan bestaat voor deze combinatie
        result = supabase.table("scanned_items")\
            .select("scanned_at")\
            .eq("user_id", user_id)\
            .eq("barcode", barcode)\
            .gte("scanned_at", time_threshold.isoformat())\
            .limit(1)\
            .execute()
        
        if result.data and len(result.data) > 0:
            last_scan_time = result.data[0]['scanned_at']
            print(f"⏭Duplicate scan detected - User {user_id} already scanned {barcode} at {last_scan_time}")
            return True
        
        return False
        
    except Exception as e:
        print(f"⚠ Error checking for duplicate scan: {e}")
        # Bij error, log wel om geen data te verliezen
        return False


def log_scan_to_supabase(
    barcode: str,
    user_id: Optional[str] = None,
    scan_mode: str = "barcode",
    allow_duplicates: bool = False,
    duplicate_window_minutes: int = 1440
) -> dict:

    if not supabase:
        print("Supabase not initialized, skipping scan log")
        return {"logged": False, "reason": "supabase_not_initialized"}
    
    try:
        # Gebruik test user ID (tijdelijk omdat gebruikers nog niet aangemaakt worden)
        user_id = user_id or "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11"
        
        # Check voor duplicaten als allow_duplicates False is
        if not allow_duplicates:
            is_duplicate = check_recent_scan(barcode, user_id, duplicate_window_minutes)
            if is_duplicate:
                return {
                    "logged": False, 
                    "reason": "duplicate_scan",
                    "message": f"Scan already logged within last {duplicate_window_minutes} minutes"
                }
        
        # Nieuwe scan loggen
        scan_data = {
            "user_id": user_id,
            "barcode": barcode,
            "scan_mode": scan_mode,
            "product_id": None,
            "scanned_at": datetime.now().isoformat(),
        }
        
        result = supabase.table("scanned_items").insert(scan_data).execute()
        print(f"Scan logged successfully for barcode: {barcode}, user: {user_id}")
        
        return {
            "logged": True,
            "reason": "success",
            "data": result.data[0] if result.data else None
        }
        
    except Exception as e:
        print(f"Error logging scan to Supabase: {e}")
        return {"logged": False, "reason": "error", "error": str(e)}


def get_product_by_barcode(
    barcode: str,
    user_id: Optional[str] = None,
    log_scan: bool = True,
    allow_duplicate_scans: bool = False,
    duplicate_window_minutes: int = 1440
) -> dict | None:
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
            scan_result = log_scan_to_supabase(
                barcode, 
                user_id,
                allow_duplicates=allow_duplicate_scans,
                duplicate_window_minutes=duplicate_window_minutes
            )
            # Voeg scan info toe aan product response
            product["scan_logged"] = scan_result["logged"]
            product["scan_status"] = scan_result["reason"]
        else:
            product["scan_logged"] = False
            product["scan_status"] = "logging_disabled"
        
        return product

    except Exception as e:
        print(f"Fout bij ophalen product uit DB: {e}")
        return None
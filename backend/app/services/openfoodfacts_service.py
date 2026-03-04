from email.header import Header
import sqlite3
import httpx
from pathlib import Path
from datetime import datetime, timedelta
from typing import Optional
import os
import requests as http_requests
from supabase import create_client, Client
from fastapi import Header

DB_PATH = Path(__file__).resolve().parent.parent / "data" / "openfoodfacts.db"

OPENFOODFACTS_API_URL = "https://world.openfoodfacts.org/api/v2/product/{barcode}.json"

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
    user_id: str,
    scan_mode: str = "barcode",
    allow_duplicates: bool = False,
    duplicate_window_minutes: int = 1440
) -> dict:

    if not user_id:
        return {"logged": False, "reason": "no_authenticated_user"}
    
    if not supabase:
        print("Supabase not initialized, skipping scan log")
        return {"logged": False, "reason": "supabase_not_initialized"}
    
    try:
        
        # Check voor duplicaten als allow_duplicates False is
        if not allow_duplicates:
            is_duplicate = check_recent_scan(barcode, user_id, duplicate_window_minutes)
            if is_duplicate:
                return {
                    "logged": False, 
                    "reason": "duplicate_scan",
                    "message": f"Scan already logged within last {duplicate_window_minutes} minutes"
                }
            product_response = supabase.table("products") \
            .select("product_id") \
            .eq("barcode", barcode) \
            .limit(1) \
            .execute()

        product_id = None

        if product_response.data and len(product_response.data) > 0:
            product_id = product_response.data[0]["product_id"]
        
        # Nieuwe scan loggen
        scan_data = {
            "user_id": user_id,
            "barcode": barcode,
            "scan_mode": scan_mode,
            "product_id": product_id,
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


def _fetch_from_openfoodfacts_api(barcode: str) -> Optional[dict]:
    """Fallback: haal product op via de publieke OpenFoodFacts API."""
    try:
        url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"
        resp = http_requests.get(url, headers={"User-Agent": "MealPrepApp/1.0"}, timeout=5)
        data = resp.json()
        if data.get("status") != 1:
            print(f"  OpenFoodFacts: barcode {barcode} niet gevonden.")
            return None
        p = data["product"]
        n = p.get("nutriments", {})
        img = p.get("image_front_url") or p.get("image_url")
        print(f"  OpenFoodFacts match: {p.get('product_name', 'Onbekend')}")
        return {
            "barcode": barcode,
            "name": p.get("product_name"),
            "brands": p.get("brands"),
            "nutriments": {
                "energy_kcal": n.get("energy-kcal_100g"),
                "proteins": n.get("proteins_100g"),
                "carbohydrates": n.get("carbohydrates_100g"),
                "fat": n.get("fat_100g"),
                "sugars": n.get("sugars_100g"),
                "salt": n.get("salt_100g"),
            },
            "image_url": img,
        }
    except Exception as e:
        print(f"  OpenFoodFacts API fout voor {barcode}: {e}")
        return None


def get_product_by_barcode(
    barcode: str,
    user_id: str,
    log_scan: bool = True,
    allow_duplicate_scans: bool = False,
    duplicate_window_minutes: int = 1440
) -> dict | None:
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Try barcode variations: original, without leading zeros, 12→13 digit
        barcode_variations = [barcode]
        stripped = barcode.lstrip('0')
        if stripped != barcode:
            barcode_variations.append(stripped)
        if len(barcode) == 12:
            barcode_variations.append('0' + barcode)
        if len(stripped) == 12:
            barcode_variations.append('0' + stripped)

        placeholders = ','.join(['?' for _ in barcode_variations])
        cursor.execute(
            f"""
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
            WHERE barcode IN ({placeholders})
            LIMIT 1
            """,
            barcode_variations,
        )

        row = cursor.fetchone()
        conn.close()

        if not row:
            # Fallback: OpenFoodFacts API
            print(f"Barcode {barcode} niet in SQLite, OpenFoodFacts API wordt geprobeerd...")
            off_product = _fetch_from_openfoodfacts_api(barcode)
            if off_product is None:
                return None
            product = off_product
        else:
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

        # Fetch image_url from Supabase if not already set (e.g. from OpenFoodFacts API)
        if not product.get("image_url") and supabase:
            try:
                img_result = supabase.table("products") \
                    .select("image_url") \
                    .eq("barcode", barcode) \
                    .limit(1) \
                    .execute()
                if img_result.data and len(img_result.data) > 0:
                    product["image_url"] = img_result.data[0].get("image_url")
                else:
                    product["image_url"] = None
            except Exception as e:
                print(f"Warning: Could not fetch image_url from Supabase: {e}")
                product["image_url"] = None
        elif not product.get("image_url"):
            product["image_url"] = None
        
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
    
def get_current_user(authorization: str | None = Header(None)):
    print("RAW AUTH HEADER:", authorization)

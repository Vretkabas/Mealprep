import sqlite3
from pathlib import Path
 
DB_PATH = Path(__file__).resolve().parent.parent / "data" / "openfoodfacts.db"
 
 
def get_db_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn
 
 
# Het product via de barcode ophalen (uit SQLite)
def get_product_by_barcode(barcode: str) -> dict | None:
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
 
        return {
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
 
    except Exception as e:
        print("Fout bij ophalen product uit DB:", e)
        return None
import sqlite3
from pathlib import Path
from typing import Optional, List
from dataclasses import dataclass
import requests

# Database path
DB_PATH = Path(__file__).parent.parent / "data" / "openfoodfacts.db"


@dataclass
class ProductMatch:
    """Represents a product match from the OpenFoodFacts database."""
    barcode: str
    product_name: Optional[str]
    brands: Optional[str]
    energy_kcal_100g: Optional[float]
    proteins_100g: Optional[float]
    carbohydrates_100g: Optional[float]
    fat_100g: Optional[float]
    sugars_100g: Optional[float]
    fiber_100g: Optional[float]
    salt_100g: Optional[float]
    match_score: Optional[float] = None


def get_db_connection():
    """Create a database connection."""
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def get_db_stats() -> dict:
    """Get database statistics."""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM products")
        total = cursor.fetchone()[0]
        conn.close()
        return {
            "status": "ok",
            "total_products": total,
            "database_path": str(DB_PATH)
        }
    except Exception as e:
        return {
            "status": "error",
            "error": str(e)
        }


def find_product_by_barcode(barcode: str) -> Optional[ProductMatch]:
    """
    Find a product by its barcode in the OpenFoodFacts database.
    Tries multiple barcode variations (with/without leading zeros).

    Args:
        barcode: The product barcode (EAN/GTIN)

    Returns:
        ProductMatch if found, None otherwise
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Generate barcode variations to try
        barcode_variations = [barcode]

        # Try without leading zeros
        stripped = barcode.lstrip('0')
        if stripped != barcode:
            barcode_variations.append(stripped)

        # Try with leading zero if it's 12 digits (UPC-A to EAN-13)
        if len(barcode) == 12:
            barcode_variations.append('0' + barcode)

        # Try stripped version with leading zero
        if len(stripped) == 12:
            barcode_variations.append('0' + stripped)

        # Search for any of the variations
        placeholders = ','.join(['?' for _ in barcode_variations])
        cursor.execute(f"""
            SELECT barcode, product_name, brands,
                   energy_kcal_100g, proteins_100g, carbohydrates_100g,
                   fat_100g, sugars_100g, fiber_100g, salt_100g
            FROM products
            WHERE barcode IN ({placeholders})
        """, barcode_variations)

        row = cursor.fetchone()
        conn.close()

        if row:
            return ProductMatch(
                barcode=row["barcode"],
                product_name=row["product_name"],
                brands=row["brands"],
                energy_kcal_100g=row["energy_kcal_100g"],
                proteins_100g=row["proteins_100g"],
                carbohydrates_100g=row["carbohydrates_100g"],
                fat_100g=row["fat_100g"],
                sugars_100g=row["sugars_100g"],
                fiber_100g=row["fiber_100g"],
                salt_100g=row["salt_100g"],
                match_score=100.0  # Exact barcode match
            )

        # Not found locally → try OpenFoodFacts API as fallback
        return find_product_by_barcode_api(barcode)

    except Exception as e:
        print(f"Error finding product by barcode: {e}")
        return None

def find_product_by_barcode_api(barcode: str) -> Optional[ProductMatch]:
    """
    Fallback: zoek product via de OpenFoodFacts API als het niet in de lokale DB zit.
    """
    url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json"

    try:
        print(f"  API lookup voor barcode {barcode}...")
        response = requests.get(url, headers={"User-Agent": "MealPrepApp/1.0"}, timeout=5)
        data = response.json()

        if data.get("status") == 1:
            product = data["product"]
            nutriments = product.get("nutriments", {})

            print(f"  API match gevonden: {product.get('product_name', 'Onbekend')}")

            return ProductMatch(
                barcode=barcode,
                product_name=product.get("product_name"),
                brands=product.get("brands"),
                energy_kcal_100g=nutriments.get("energy-kcal_100g"),
                proteins_100g=nutriments.get("proteins_100g"),
                carbohydrates_100g=nutriments.get("carbohydrates_100g"),
                fat_100g=nutriments.get("fat_100g"),
                sugars_100g=nutriments.get("sugars_100g"),
                fiber_100g=nutriments.get("fiber_100g"),
                salt_100g=nutriments.get("salt_100g"),
                match_score=100.0
            )
        else:
            print(f"  API: barcode {barcode} niet gevonden.")
            return None

    except Exception as e:
        print(f"  API error voor {barcode}: {e}")
        return None

def find_product_by_name(name: str, limit: int = 5, min_score: float = 70.0) -> List[ProductMatch]:
    """
    Find products by name using fuzzy matching.

    Args:
        name: The product name to search for
        limit: Maximum number of results
        min_score: Minimum match score (0-100)

    Returns:
        List of ProductMatch objects sorted by match score
    """
    try:
        conn = get_db_connection()
        cursor = conn.cursor()

        # Simple LIKE search for now - can be improved with FTS5 or external fuzzy library
        search_term = f"%{name}%"
        cursor.execute("""
            SELECT barcode, product_name, brands,
                   energy_kcal_100g, proteins_100g, carbohydrates_100g,
                   fat_100g, sugars_100g, fiber_100g, salt_100g
            FROM products
            WHERE product_name LIKE ?
            LIMIT ?
        """, (search_term, limit))

        rows = cursor.fetchall()
        conn.close()

        results = []
        for row in rows:
            # Simple score based on name similarity (placeholder)
            score = 75.0 if name.lower() in (row["product_name"] or "").lower() else 50.0

            if score >= min_score:
                results.append(ProductMatch(
                    barcode=row["barcode"],
                    product_name=row["product_name"],
                    brands=row["brands"],
                    energy_kcal_100g=row["energy_kcal_100g"],
                    proteins_100g=row["proteins_100g"],
                    carbohydrates_100g=row["carbohydrates_100g"],
                    fat_100g=row["fat_100g"],
                    sugars_100g=row["sugars_100g"],
                    fiber_100g=row["fiber_100g"],
                    salt_100g=row["salt_100g"],
                    match_score=score
                ))

        return sorted(results, key=lambda x: x.match_score or 0, reverse=True)

    except Exception as e:
        print(f"Error finding product by name: {e}")
        return []

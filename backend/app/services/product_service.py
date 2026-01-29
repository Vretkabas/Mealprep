"""
Product Service - Fuzzy matching with OpenFoodFacts SQLite database

Usage:
    from app.services.product_service import find_product_by_name, get_db_stats

    # Search product by name
    result = find_product_by_name("Danio Strawberry")

    # Check database status
    stats = get_db_stats()
"""

import sqlite3
from pathlib import Path
from typing import Optional
from dataclasses import dataclass

# Database path
DB_PATH = Path(__file__).parent.parent / "data" / "openfoodfacts.db"


@dataclass
class ProductMatch:
    """Result of a product match."""
    barcode: str
    product_name: str
    brands: Optional[str]
    energy_kcal_100g: Optional[float]
    proteins_100g: Optional[float]
    carbohydrates_100g: Optional[float]
    fat_100g: Optional[float]
    sugars_100g: Optional[float]
    fiber_100g: Optional[float]
    salt_100g: Optional[float]
    match_score: float  # 0-100, how good the match is


def check_database() -> bool:
    """Check if the OpenFoodFacts database exists."""
    if not DB_PATH.exists():
        print(f"[ERROR] OpenFoodFacts database not found: {DB_PATH}")
        print(f"[INFO] Download from: https://1drv.ms/u/c/75a5af5a3877ff10/IQDivoEEZuAlRLsNN2fAnIGvAY1J-C2xwAUR7RSdjWqyPyM?e=cS2IbD")
        print(f"[INFO] Place in: backend/app/data/openfoodfacts.db")
        return False
    return True


def get_db_stats() -> dict:
    """Get statistics about the database."""
    if not check_database():
        return {"error": "Database not found", "exists": False}

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM products")
    total = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM products WHERE energy_kcal_100g IS NOT NULL")
    with_macros = cursor.fetchone()[0]

    conn.close()

    return {
        "exists": True,
        "total_products": total,
        "products_with_macros": with_macros,
        "database_path": str(DB_PATH)
    }


def find_product_by_name(
    search_name: str,
    limit: int = 5,
    min_score: float = 50.0
) -> list[ProductMatch]:
    """
    Search products by name with fuzzy matching.

    Args:
        search_name: The name to search for (e.g. "Danio Strawberry 180g")
        limit: Maximum number of results
        min_score: Minimum match score (0-100)

    Returns:
        List of ProductMatch objects, sorted by relevance
    """
    if not check_database():
        return []

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Normalize the search name
    search_lower = search_name.lower().strip()
    search_words = search_lower.split()

    # Strategy 1: Exact match (score 100)
    cursor.execute("""
        SELECT barcode, product_name, brands,
               energy_kcal_100g, proteins_100g, carbohydrates_100g,
               fat_100g, sugars_100g, fiber_100g, salt_100g
        FROM products
        WHERE LOWER(product_name) = ?
        LIMIT ?
    """, (search_lower, limit))

    exact_matches = cursor.fetchall()
    if exact_matches:
        conn.close()
        return [_row_to_product(row, 100.0) for row in exact_matches]

    # Strategy 2: LIKE with wildcards (score 80-90)
    cursor.execute("""
        SELECT barcode, product_name, brands,
               energy_kcal_100g, proteins_100g, carbohydrates_100g,
               fat_100g, sugars_100g, fiber_100g, salt_100g
        FROM products
        WHERE LOWER(product_name) LIKE ?
        LIMIT ?
    """, (f"%{search_lower}%", limit * 2))

    like_matches = cursor.fetchall()

    # Strategy 3: Search by individual words
    word_matches = []
    if len(search_words) >= 2:
        # Search products that contain ALL words
        where_clauses = " AND ".join([f"LOWER(product_name) LIKE ?" for _ in search_words])
        params = [f"%{word}%" for word in search_words] + [limit * 2]

        cursor.execute(f"""
            SELECT barcode, product_name, brands,
                   energy_kcal_100g, proteins_100g, carbohydrates_100g,
                   fat_100g, sugars_100g, fiber_100g, salt_100g
            FROM products
            WHERE {where_clauses}
            LIMIT ?
        """, params)

        word_matches = cursor.fetchall()

    conn.close()

    # Combine and score results
    all_matches = {}

    for row in like_matches:
        barcode = row[0]
        if barcode not in all_matches:
            score = _calculate_score(search_lower, row[1])
            if score >= min_score:
                all_matches[barcode] = (row, score)

    for row in word_matches:
        barcode = row[0]
        if barcode not in all_matches:
            score = _calculate_score(search_lower, row[1])
            if score >= min_score:
                all_matches[barcode] = (row, score)
        else:
            # Update score if word match is better
            existing_score = all_matches[barcode][1]
            new_score = _calculate_score(search_lower, row[1])
            if new_score > existing_score:
                all_matches[barcode] = (row, new_score)

    # Sort by score and return
    sorted_matches = sorted(all_matches.values(), key=lambda x: x[1], reverse=True)

    return [_row_to_product(row, score) for row, score in sorted_matches[:limit]]


def find_product_by_barcode(barcode: str) -> Optional[ProductMatch]:
    """Find product by exact barcode."""
    if not check_database():
        return None

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT barcode, product_name, brands,
               energy_kcal_100g, proteins_100g, carbohydrates_100g,
               fat_100g, sugars_100g, fiber_100g, salt_100g
        FROM products
        WHERE barcode = ?
    """, (barcode,))

    row = cursor.fetchone()
    conn.close()

    if row:
        return _row_to_product(row, 100.0)
    return None


def _calculate_score(search: str, product_name: str) -> float:
    """
    Calculate a simple match score between search term and product name.

    Returns: score from 0-100
    """
    if not product_name:
        return 0.0

    search_lower = search.lower()
    name_lower = product_name.lower()

    # Exact match
    if search_lower == name_lower:
        return 100.0

    # Contains full search term
    if search_lower in name_lower:
        # Shorter product name vs search term = better match
        ratio = len(search_lower) / len(name_lower)
        return 70.0 + (ratio * 20.0)  # 70-90

    # Check how many words match
    search_words = set(search_lower.split())
    name_words = set(name_lower.split())

    if not search_words:
        return 0.0

    matching_words = search_words & name_words
    word_ratio = len(matching_words) / len(search_words)

    return word_ratio * 70.0  # 0-70


def _row_to_product(row: tuple, score: float) -> ProductMatch:
    """Convert database row to ProductMatch object."""
    return ProductMatch(
        barcode=row[0],
        product_name=row[1],
        brands=row[2],
        energy_kcal_100g=row[3],
        proteins_100g=row[4],
        carbohydrates_100g=row[5],
        fat_100g=row[6],
        sugars_100g=row[7],
        fiber_100g=row[8],
        salt_100g=row[9],
        match_score=score
    )

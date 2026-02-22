"""
Colruyt Product Import Pipeline
================================
1. Download all products from the GCS bucket (BelgianNoise)
2. Per product: fetch barcode via RTI redirect
3. Save to Supabase products table with Colruyt-specific fields

Resume-capable: skips products that already have a colruyt_product_id in the DB.
Rate limited: 0.5-1s delay between RTI requests.

Usage:
    python colruyt_all_products.py              # Full import
    python colruyt_all_products.py --test 5     # Test with first 5 products
    python colruyt_all_products.py --dry-run    # Download + RTI, but don't save to DB
"""
 
import requests
import json
import sys
import os
import re
import time
import random
import argparse
import asyncio
from datetime import datetime
 
# Add backend to path for product_service
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'backend'))
 
from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), '..', '..', '.env'))
 
import asyncpg
 
# config
 
DATABASE_URL = os.getenv("DATABASE_URL")
RTI_BASE_URL = "https://rti.colruytgroup.com/nl/product-info"
GCS_LISTING_URL = "https://storage.googleapis.com/storage/v1/b/colruyt-products/o"
GCS_DOWNLOAD_BASE = "https://storage.googleapis.com/colruyt-products"
USER_AGENT = "MealPrepApp/1.0"
RTI_DELAY_MIN = 0.4
RTI_DELAY_MAX = 0.8
 
 
# download from GCS bucket
 
def download_colruyt_products() -> list[dict]:
    """Download the latest Colruyt product dump from the GCS bucket."""
    print("=" * 60)
    print("STEP 1: Downloading Colruyt products from GCS bucket")
    print("=" * 60)
 
    # List files in bucket
    params = {"prefix": "colruyt-products/", "maxResults": 1000}
    response = requests.get(GCS_LISTING_URL, params=params).json()
    items = response.get("items", [])
 
    if not items:
        print("ERROR: No files found in bucket!")
        return []
 
    # Get the latest file (sorted by name = sorted by date)
    latest = sorted(items, key=lambda x: x["name"])[-1]
    size_mb = int(latest["size"]) / 1e6
    print(f"Latest file: {latest['name']} ({size_mb:.1f} MB)")
 
    # Download it
    download_url = f"{GCS_DOWNLOAD_BASE}/{latest['name']}"
    print(f"Downloading...")
    products = requests.get(download_url).json()
    print(f"✓ {len(products)} products downloaded")
 
    return products
 
 
# barcode fetching via RTI
 
def fetch_barcode_from_rti(technical_article_nr: str) -> str | None:
    """
    Fetch the EAN barcode via the RTI redirect.
    Input:  https://rti.colruytgroup.com/nl/product-info/{technicalArticleNumber}
    Output: The barcode from the # fragment of the redirect URL.
    """
    url = f"{RTI_BASE_URL}/{technical_article_nr}"
 
    try:
        resp = requests.get(
            url,
            headers={"User-Agent": USER_AGENT},
            allow_redirects=True,
            timeout=10
        )
 
        final_url = resp.url
 
        # Barcode is in the fragment after #
        if "#" in final_url:
            barcode = final_url.split("#")[-1].strip()
 
            # Validate: must be 8-14 digits (EAN-8, EAN-13, GTIN-14)
            if re.match(r'^\d{8,14}$', barcode):
                return barcode
            else:
                return None
 
        # Sometimes the barcode is in the page content instead of the fragment
        # Check if there is a data-gtin attribute in the response
        gtin_match = re.search(r'data-gtin="(\d{8,14})"', resp.text)
        if gtin_match:
            return gtin_match.group(1)
 
        return None
 
    except Exception as e:
        print(f"    RTI error for {technical_article_nr}: {e}")
        return None
 
 
def is_valid_ean(barcode: str) -> bool:
    """Validate whether a barcode has a valid EAN-13 format."""
    return bool(barcode and re.match(r'^\d{8,14}$', barcode))
 
 
# save to db
 
async def get_existing_colruyt_ids(pool: asyncpg.Pool) -> set:
    """Fetch all colruyt_product_ids that are already in the DB (for resume)."""
    async with pool.acquire() as conn:
        rows = await conn.fetch(
            "SELECT colruyt_product_id FROM products WHERE colruyt_product_id IS NOT NULL"
        )
        return {row["colruyt_product_id"] for row in rows}
 
 
async def save_product_to_db(pool: asyncpg.Pool, product: dict, barcode: str | None):
    """Save a Colruyt product to the database."""
    import uuid
 
    product_id = str(uuid.uuid4())
    colruyt_product_id = str(product.get("productId", ""))
    product_name = product.get("LongName") or product.get("name") or "Unknown"
    brand = product.get("seoBrand") or product.get("brand")
    image_url = product.get("fullImage")
    content = product.get("content")
    colruyt_category = product.get("topCategoryName")
    colruyt_technical_nr = str(product.get("technicalArticleNumber", ""))
    colruyt_commercial_nr = str(product.get("commercialArticleNumber", ""))
 
    # Price
    price = None
    price_data = product.get("price")
    if price_data and isinstance(price_data, dict):
        price = price_data.get("basicPrice")
 
    # Barcode: use RTI barcode, or technicalArticleNumber as fallback
    effective_barcode = barcode or f"COLRUYT-{colruyt_technical_nr}"
 
    async with pool.acquire() as conn:
        try:
            # check if product with same colruyt_product_id already exists
            existing = await conn.fetchrow(
                "SELECT product_id, barcode FROM products WHERE colruyt_product_id = $1",
                colruyt_product_id
            )
 
            if existing:
                # Update existing product
                await conn.execute("""
                    UPDATE products SET
                        product_name = COALESCE($2, product_name),
                        brand = COALESCE($3, brand),
                        image_url = COALESCE($4, image_url),
                        content = COALESCE($5, content),
                        colruyt_category = COALESCE($6, colruyt_category),
                        colruyt_technical_nr = COALESCE($7, colruyt_technical_nr),
                        colruyt_commercial_nr = COALESCE($8, colruyt_commercial_nr),
                        price = COALESCE($9, price),
                        barcode = COALESCE($10, barcode)
                    WHERE colruyt_product_id = $1
                """,
                    colruyt_product_id, product_name, brand, image_url,
                    content, colruyt_category, colruyt_technical_nr,
                    colruyt_commercial_nr, price, effective_barcode
                )
                return "updated"
            else:
                # Check if barcode already exists
                existing_barcode = await conn.fetchrow(
                    "SELECT product_id FROM products WHERE barcode = $1",
                    effective_barcode
                )
 
                if existing_barcode:
                    # Barcode already exists → update with colruyt info + link via colruyt_product_id
                    await conn.execute("""
                        UPDATE products SET
                            colruyt_product_id = $2,
                            colruyt_technical_nr = $3,
                            colruyt_commercial_nr = $4,
                            colruyt_category = $5,
                            content = COALESCE($6, content),
                            price = COALESCE($7, price),
                            image_url = COALESCE($8, image_url)
                        WHERE barcode = $1
                    """,
                        effective_barcode, colruyt_product_id,
                        colruyt_technical_nr, colruyt_commercial_nr,
                        colruyt_category, content, price, image_url
                    )
                    return "linked"
                else:
                    # New product
                    await conn.execute("""
                        INSERT INTO products (
                            product_id, barcode, product_name, brand, image_url,
                            content, colruyt_category, colruyt_product_id,
                            colruyt_technical_nr, colruyt_commercial_nr, price
                        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                    """,
                        product_id, effective_barcode, product_name, brand,
                        image_url, content, colruyt_category, colruyt_product_id,
                        colruyt_technical_nr, colruyt_commercial_nr, price
                    )
                    return "inserted"
 
        except asyncpg.UniqueViolationError:
            return "duplicate"
        except Exception as e:
            print(f"    DB error for {colruyt_product_id}: {e}")
            return "error"
 
 
# main
 
async def run_pipeline(test_limit: int = 0, dry_run: bool = False):
    """
    Main pipeline:
    1. Download products from GCS bucket
    2. Per product: fetch barcode via RTI
    3. Save to Supabase
    """
 
    # Step 1: Download
    products = download_colruyt_products()
    if not products:
        return
 
    # Limit for testing
    if test_limit > 0:
        products = products[:test_limit]
        print(f"\n⚠ TEST MODE: Only first {test_limit} products")
 
    # Step 2+3: Connect to DB + process products
    print("\n" + "=" * 60)
    print("STEP 2+3: Fetching barcode via RTI + saving to database")
    print("=" * 60)
 
    pool = None
    if not dry_run:
        pool = await asyncpg.create_pool(DATABASE_URL)
        existing_ids = await get_existing_colruyt_ids(pool)
        print(f"Already in DB: {len(existing_ids)} Colruyt products")
    else:
        existing_ids = set()
        print("⚠ DRY RUN: No database operations")
 
    # Stats
    stats = {
        "total": len(products),
        "skipped_existing": 0,
        "skipped_no_technical": 0,
        "barcode_found": 0,
        "barcode_not_found": 0,
        "inserted": 0,
        "updated": 0,
        "linked": 0,
        "duplicate": 0,
        "error": 0,
    }
 
    start_time = time.time()
 
    for i, product in enumerate(products):
        colruyt_id = str(product.get("productId", ""))
        technical_nr = str(product.get("technicalArticleNumber", ""))
        name = product.get("LongName") or product.get("name") or "?"
 
        # skip if in db
        if colruyt_id in existing_ids:
            stats["skipped_existing"] += 1
            continue
 
        # Skip if no technicalArticleNumber
        if not technical_nr or technical_nr == "None":
            stats["skipped_no_technical"] += 1
            continue
 
        # Progress logging every 100 products
        if (i + 1) % 100 == 0 or i == 0:
            elapsed = time.time() - start_time
            rate = (i + 1 - stats["skipped_existing"]) / elapsed if elapsed > 0 else 0
            remaining = (stats["total"] - i - 1) / rate / 60 if rate > 0 else 0
            print(f"\n[{i+1}/{stats['total']}] {rate:.1f} prod/sec | ~{remaining:.0f} min remaining")
 
        # Fetch barcode via RTI
        barcode = fetch_barcode_from_rti(technical_nr)
 
        if barcode:
            stats["barcode_found"] += 1
            print(f"  ✓ {name[:50]:50s} → EAN: {barcode}")
        else:
            stats["barcode_not_found"] += 1
            print(f"  ✗ {name[:50]:50s} → no barcode")
 
        # Save to DB
        if not dry_run and pool:
            result = await save_product_to_db(pool, product, barcode)
            stats[result] = stats.get(result, 0) + 1
 
        # Rate limiting
        time.sleep(random.uniform(RTI_DELAY_MIN, RTI_DELAY_MAX))
 
    # Close pool
    if pool:
        await pool.close()
 
    # Print stats
    elapsed = time.time() - start_time
    print("\n" + "=" * 60)
    print("RESULTS")
    print("=" * 60)
    print(f"Total products:          {stats['total']}")
    print(f"Skipped (already in DB): {stats['skipped_existing']}")
    print(f"Skipped (no TNR):        {stats['skipped_no_technical']}")
    print(f"Barcode found (RTI):     {stats['barcode_found']}")
    print(f"Barcode not found:       {stats['barcode_not_found']}")
    if not dry_run:
        print(f"Newly inserted:          {stats['inserted']}")
        print(f"Updated:                 {stats['updated']}")
        print(f"Linked (barcode match):  {stats['linked']}")
        print(f"Duplicates skipped:      {stats['duplicate']}")
        print(f"Errors:                  {stats['error']}")
    print(f"Time:                    {elapsed/60:.1f} minutes")
    print("=" * 60)
 
 
# for cli extra testing and flexibility
 
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Colruyt Product Import Pipeline")
    parser.add_argument("--test", type=int, default=0, help="Test with N products (0 = all)")
    parser.add_argument("--dry-run", action="store_true", help="Download + RTI, but don't save to DB")
    args = parser.parse_args()
 
    asyncio.run(run_pipeline(test_limit=args.test, dry_run=args.dry_run))
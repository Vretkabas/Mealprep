from playwright.sync_api import sync_playwright, Playwright
from rich import print
from bs4 import BeautifulSoup
import re
import random
import time
import requests

def run(playwright: Playwright):
    chrome = playwright.chromium

    # Launch browser with explicit args to avoid bot detection
    browser = chrome.launch(
        headless=True,
        args=[
            "--disable-blink-features=AutomationControlled",
            "--disable-dev-shm-usage",
            "--no-sandbox",
        ]
    )

    # Create context with custom settings
    context = browser.new_context(
        viewport={"width": 1920, "height": 1080},
        user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        locale="nl-BE",
    )

    page = context.new_page()

    # Hide webdriver property to avoid detection
    page.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {
            get: () => undefined
        });
    """)

    # Sets to collect all product URLs
    product_urls_single = set()
    product_urls_multi = set()

    # Promotion dates
    product_promotion_from = None
    product_promotion_to = None

    # Food-related categories to filter
    CATEGORIES_TO_SELECT = [
        "topCategory-Bereidingen/Charcuterie/Vis/Veggie",
        "topCategory-Brood/Ontbijt",
        "topCategory-Chips/Borrelhapjes",
        "topCategory-Colruyt-beenhouwrij",
        "topCategory-Conserven",
        "topCategory-Diepvries",
        "topCategory-Dranken",
        "topCategory-Gezondheid",
        "topCategory-Groenten en fruit",
        "topCategory-Kruidenierswaren/Droge voeding",
        "topCategory-Zuivel",
    ]

    # Load first page to set up cookies and filters
    print(f"\n[yellow]Loading first page to set up filters...[/yellow]")
    page.goto("https://www.colruyt.be/nl/acties?page=1", wait_until="domcontentloaded")

    # Handle cookie popup
    try:
        cookie_button = page.locator("#onetrust-accept-btn-handler")
        cookie_button.wait_for(state="visible", timeout=10000)
        cookie_button.click()
        print("[green]Cookies accepted[/green]")
    except Exception as e:
        print(f"[yellow]Cookie popup not found or already accepted: {e}[/yellow]")

    time.sleep(random.uniform(1.5, 2.5))

    # Click "More filters" button to show all categories
    print(f"\n[yellow]Opening more filters...[/yellow]")
    try:
        more_filters_btn = page.get_by_text("Meer filters", exact=False)
        if more_filters_btn.count() > 0:
            more_filters_btn.first.scroll_into_view_if_needed()
            time.sleep(random.uniform(0.3, 0.6))
            more_filters_btn.first.click()
            print("[green]More filters opened[/green]")
            time.sleep(random.uniform(0.5, 1.0))
        else:
            print("[yellow]More filters button not found[/yellow]")
    except Exception as e:
        print(f"[yellow]More filters button not found: {e}[/yellow]")

    # Select categories using XPath for IDs with special characters
    print(f"\n[yellow]Selecting category filters...[/yellow]")
    for category_id in CATEGORIES_TO_SELECT:
        try:
            label = page.locator(f"//label[@for='{category_id}']")
            if label.count() > 0:
                label.scroll_into_view_if_needed()
                time.sleep(random.uniform(0.2, 0.5))
                label.click()
                print(f"[green]{category_id}[/green]")
                time.sleep(random.uniform(0.3, 0.7))
            else:
                print(f"[yellow]{category_id} not found[/yellow]")
        except Exception as e:
            print(f"[red]{category_id}: {e}[/red]")

    # Wait for page to reload with filters applied
    print(f"\n[yellow]Waiting for filtered results...[/yellow]")
    time.sleep(random.uniform(2.0, 3.0))

    # TEST MODE: Set to True to only scrape 1 page for faster testing
    TEST_MODE = False
    MAX_TEST_PAGES = 99

    index = 1
    while True:
        print(f"\n[yellow]Processing page {index}...[/yellow]")

        # Wait for product cards to load
        try:
            page.wait_for_selector("a.card.card--article, a.card.promotion-card", timeout=15000)
        except Exception as e:
            print(f"[yellow]Waiting for cards: {e}[/yellow]")

        # Random delay to simulate human behavior
        time.sleep(random.uniform(1.5, 3.0))

        # Parse page content
        soup = BeautifulSoup(page.content(), "html.parser")

        # Get promotion dates (only on first page)
        if index == 1:
            date_div = soup.find("div", class_="promo-overview-date")
            if date_div:
                date_pattern = r"(\d{1,2}/\d{1,2}(?:/\d{4})?)"
                dates = re.findall(date_pattern, date_div.get_text())
                if len(dates) >= 2:
                    product_promotion_from = dates[0]
                    product_promotion_to = dates[1]
                    print(f"[cyan]Promotions from {product_promotion_from} to {product_promotion_to}[/cyan]")

        # Track how many NEW products we find on this page
        new_single = 0
        new_multi = 0

        # Get single product cards
        for card in soup.select("a.card.card--article"):
            href = card.get("href")
            if href and "undefined" not in href:
                full_url = "https://www.colruyt.be" + href
                if full_url not in product_urls_single:
                    product_urls_single.add(full_url)
                    new_single += 1
                    print(f"[blue]Single:[/blue] {full_url}")

        # Get multi product cards
        for card in soup.select("a.card.promotion-card"):
            href = card.get("href")
            if href and "undefined" not in href:
                full_url = "https://www.colruyt.be" + href
                if full_url not in product_urls_multi:
                    product_urls_multi.add(full_url)
                    new_multi += 1
                    print(f"[green]Multi:[/green] {full_url}")

        print(f"[cyan]Page {index}: +{new_single} single, +{new_multi} multi[/cyan]")
        print(f"[cyan]Total: {len(product_urls_single)} single, {len(product_urls_multi)} multi[/cyan]")

        # If no new products found, we've reached the end
        if new_single == 0 and new_multi == 0:
            print(f"\n[yellow]No new products on page {index}, stopping.[/yellow]")
            break

        # TEST MODE: Stop after MAX_TEST_PAGES
        if TEST_MODE and index >= MAX_TEST_PAGES:
            print(f"\n[yellow]TEST MODE: Stopping after {MAX_TEST_PAGES} page(s)[/yellow]")
            break

        # Try to navigate to next page via "Load more" button
        try:
            # Find the "Meer bekijken" (Load more) button
            load_more_btn = page.locator("a.load-more__btn, a.btn--primary.load-more__btn")

            # If not found, try by text
            if load_more_btn.count() == 0:
                load_more_btn = page.get_by_text("Meer bekijken", exact=False)

            if load_more_btn.count() > 0 and load_more_btn.first.is_visible():
                load_more_btn.first.scroll_into_view_if_needed()
                time.sleep(random.uniform(0.5, 1.0))
                load_more_btn.first.click()
                print(f"[green]Loading more products...[/green]")

                # Wait for new content to load
                time.sleep(random.uniform(2.0, 3.5))
                index += 1
            else:
                print(f"\n[yellow]No 'Load more' button found, end reached.[/yellow]")
                break

        except Exception as e:
            print(f"\n[yellow]Could not load more: {e}[/yellow]")
            break

    print(f"\n[bold green]COLLECTED - Single: {len(product_urls_single)}, Multi: {len(product_urls_multi)}[/bold green]")

    # Visit multi-deal pages to get individual product URLs
    print(f"\n[bold yellow]Processing multi-deals to get individual products...[/bold yellow]")

    for i, multi_url in enumerate(product_urls_multi, 1):
        print(f"\n[yellow]Multi-deal {i}/{len(product_urls_multi)}: {multi_url}[/yellow]")

        try:
            page.goto(multi_url, wait_until="domcontentloaded")

            # Wait for product cards
            try:
                page.wait_for_selector("a.card.card--article", timeout=10000)
            except:
                print(f"[red]No products found on this page[/red]")
                continue

            # Random delay
            time.sleep(random.uniform(1.5, 3.0))

            # Parse the page
            soup = BeautifulSoup(page.content(), "html.parser")

            # Get all individual product URLs
            new_from_multi = 0
            for card in soup.select("a.card.card--article"):
                href = card.get("href")
                if href and "undefined" not in href:
                    full_url = "https://www.colruyt.be" + href
                    # Check if URL already exists in single set
                    if full_url not in product_urls_single:
                        product_urls_single.add(full_url)
                        new_from_multi += 1

            print(f"[green]+{new_from_multi} new products from this multi-deal[/green]")

            # Extra delay between pages
            time.sleep(random.uniform(2.0, 4.0))

        except Exception as e:
            print(f"[red]Error processing multi-deal: {e}[/red]")
            continue

    print(f"\n[bold green]========================================[/bold green]")
    print(f"[bold green]FINAL TOTAL: {len(product_urls_single)} unique products[/bold green]")
    print(f"[bold green]========================================[/bold green]")

    # Fetch product details (discount + barcode) - 5 pages at a time
    print(f"\n[bold yellow]Fetching product details (discount + barcode)...[/bold yellow]")

    product_data = []  # List to store all product data
    product_list = list(product_urls_single)

    # Create 5 pages for parallel scraping
    pages = [context.new_page() for _ in range(5)]

    # Hide webdriver for all pages
    for p in pages:
        p.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {
                get: () => undefined
            });
        """)

    def scrape_product(page_obj, product_url, product_index, total):
        """Scrape a single product for discount and barcode(s)"""
        try:
            print(f"[yellow]Product {product_index}/{total}: {product_url}[/yellow]")

            page_obj.goto(product_url, wait_until="domcontentloaded")
            time.sleep(random.uniform(1.0, 2.0))

            soup = BeautifulSoup(page_obj.content(), "html.parser")

            # Get product name from h1
            product_name = None
            h1 = soup.find("h1")
            if h1:
                product_name = h1.get_text(strip=True)

            # Get discount - grab the full promo text from promos__row--benefits
            discount = None

            promo_div = soup.find("div", class_="promos__row--benefits")
            if promo_div:
                # Get the main discount from <strong> (e.g. "-20%", "2+1 GRATIS")
                strong = promo_div.find("strong")
                if strong:
                    discount = strong.get_text(strip=True)

                # Check for extra context in promos__description-note (e.g. "vanaf 16 st")
                note_span = promo_div.find("span", class_="promos__description-note")
                if note_span and discount:
                    note_text = note_span.get_text(strip=True)
                    if note_text:
                        discount = f"{discount} {note_text}"

            # Fallback: try span.promos__description or promos__description-text
            if not discount:
                for class_name in ["promos__description", "promos__description-text"]:
                    promo_span = soup.find("span", class_=class_name)
                    if promo_span:
                        strong = promo_span.find("strong")
                        if strong:
                            discount = strong.get_text(strip=True)
                            # Also grab note if present
                            note_span = promo_span.find("span", class_="promos__description-note")
                            if note_span:
                                note_text = note_span.get_text(strip=True)
                                if note_text:
                                    discount = f"{discount} {note_text}"
                            break

            # Last resort: any <strong> with % or GRATIS
            if not discount:
                for strong in soup.find_all("strong"):
                    text = strong.get_text(strip=True)
                    if "%" in text or "GRATIS" in text.upper():
                        discount = text
                        break

            # Parse price from price-info__price-label spans
            price = None
            price_label = soup.find("div", class_="price-info__price-label")
            if price_label:
                rounded = price_label.find("span", class_="rounded-number")
                decimal = price_label.find("span", class_="decimal")
                if rounded and decimal:
                    try:
                        price = float(f"{rounded.get_text(strip=True)}.{decimal.get_text(strip=True)}")
                    except ValueError:
                        price = None

            # Get link to fic.colruytgroup.com or rti.colruytgroup.com for barcodes
            barcodes = []

            # Try multiple locations for the product info link
            info_link = None
            info_url = None

            # Helper function to check if URL is a valid product info link
            def is_product_info_url(url):
                if not url:
                    return False
                return "fic.colruytgroup.com" in url or "rti.colruytgroup.com" in url

            # Method 1: Look in product-detail__product-description-details
            detail_div = soup.find("div", class_="product-detail__product-description-details")
            if detail_div:
                info_link = detail_div.find("a", href=lambda x: is_product_info_url(x))

            # Method 2: Look anywhere on the page for fic or rti link
            if not info_link:
                info_link = soup.find("a", href=lambda x: is_product_info_url(x))

            # Method 3: Look for link with "productinfo" or "voedingswaarde" text
            if not info_link:
                for link in soup.find_all("a"):
                    link_text = link.get_text(strip=True).lower()
                    if "productinfo" in link_text or "voedingswaarde" in link_text or "product informatie" in link_text:
                        href = link.get("href", "")
                        if is_product_info_url(href):
                            info_link = link
                            break

            if info_link:
                info_url = info_link.get("href")
                print(f"[cyan]  -> Product info URL: {info_url}[/cyan]")

                # Visit product info page to get barcode(s)
                try:
                    page_obj.goto(info_url, wait_until="domcontentloaded")
                    time.sleep(random.uniform(0.5, 1.5))

                    info_soup = BeautifulSoup(page_obj.content(), "html.parser")

                    def normalize_barcode(raw: str) -> str:
                        """Strip leading zeros to match how barcodes are stored in the products table."""
                        return raw.lstrip('0') if raw else raw

                    # Method 1: Find ALL elements with data-gtin attribute
                    gtin_elements = info_soup.find_all(attrs={"data-gtin": True})
                    for elem in gtin_elements:
                        gtin = normalize_barcode(elem.get("data-gtin"))
                        if gtin and gtin not in barcodes:
                            barcodes.append(gtin)

                    # Method 2: Look for barcode-list container with spans
                    barcode_list = info_soup.find(attrs={"aria-controls": "barcode-list"})
                    if barcode_list:
                        parent = barcode_list.find_parent()
                        if parent:
                            for span in parent.find_all("span", attrs={"data-gtin": True}):
                                gtin = normalize_barcode(span.get("data-gtin"))
                                if gtin and gtin not in barcodes:
                                    barcodes.append(gtin)

                    # Method 3: Check span with id="current_gtin" (fallback)
                    if not barcodes:
                        gtin_span = info_soup.find("span", id="current_gtin")
                        if gtin_span:
                            gtin_text = normalize_barcode(gtin_span.get_text(strip=True))
                            if gtin_text and gtin_text not in barcodes:
                                barcodes.append(gtin_text)

                    # Method 4: Look for GTIN/EAN in table rows or definition lists (RTI pages)
                    if not barcodes:
                        # Look for table cells or spans with "GTIN", "EAN", "Barcode" labels
                        for elem in info_soup.find_all(["td", "dd", "span", "div"]):
                            text = elem.get_text(strip=True)
                            # Check if it's a 13-14 digit barcode
                            if re.match(r'^\d{12,14}$', text):
                                normalized = normalize_barcode(text)
                                if normalized not in barcodes:
                                    barcodes.append(normalized)

                    # Method 5: Search page text for barcode patterns
                    if not barcodes:
                        page_text = info_soup.get_text()
                        # Find all 13-digit numbers (EAN-13 format)
                        ean_matches = re.findall(r'\b(\d{13})\b', page_text)
                        for ean in ean_matches:
                            normalized = normalize_barcode(ean)
                            if normalized not in barcodes:
                                barcodes.append(normalized)

                except Exception as e:
                    print(f"[red]Error fetching barcode: {e}[/red]")
            else:
                print(f"[red]  -> No product info link (fic/rti) found on product page[/red]")

            return {
                "url": product_url,
                "name": product_name,
                "discount": discount,
                "price": price,
                "barcodes": barcodes  # Return list of barcodes instead of single
            }

        except Exception as e:
            print(f"[red]Error with product {product_url}: {e}[/red]")
            return {
                "url": product_url,
                "name": None,
                "discount": None,
                "price": None,
                "barcodes": []
            }

    # Process products in batches of 5
    total_products = len(product_list)
    for batch_start in range(0, total_products, 5):
        batch_end = min(batch_start + 5, total_products)
        batch = product_list[batch_start:batch_end]

        print(f"\n[cyan]Batch {batch_start//5 + 1}: products {batch_start + 1} - {batch_end}[/cyan]")

        # Scrape each product in the batch sequentially (each page handles 1 product)
        for i, product_url in enumerate(batch):
            page_to_use = pages[i]
            result = scrape_product(page_to_use, product_url, batch_start + i + 1, total_products)

            # Only add if both discount AND at least one barcode are present
            if result["discount"] and result["barcodes"]:
                # Add each barcode as separate entry (API will determine which one matches)
                for barcode in result["barcodes"]:
                    product_data.append({
                        "url": result["url"],
                        "name": result.get("name"),
                        "discount": result["discount"],
                        "price": result.get("price"),
                        "barcode": barcode
                    })
                barcodes_str = ", ".join(result["barcodes"])
                price_str = f"€{result.get('price')}" if result.get("price") else "N/A"
                print(f"[green]  {result.get('name', '?')} | Discount: {result['discount']} | Price: {price_str} | Barcodes: {barcodes_str}[/green]")
            else:
                missing = []
                if not result["discount"]:
                    missing.append("discount")
                if not result["barcodes"]:
                    missing.append("barcode")
                print(f"[red]  Skipped (missing {', '.join(missing)})[/red]")

        # Delay between batches
        time.sleep(random.uniform(2.0, 3.0))

    # Close extra pages
    for p in pages:
        p.close()

    print(f"\n[bold green]========================================[/bold green]")
    print(f"[bold green]SCRAPING COMPLETE![/bold green]")
    print(f"[bold green]Total scraped: {total_products} products[/bold green]")
    print(f"[bold green]Valid for API: {len(product_data)} products[/bold green]")
    print(f"[bold green]========================================[/bold green]")

    # Print all valid results
    print(f"\n[bold cyan]All valid products (with discount and barcode):[/bold cyan]")
    for data in product_data:
        print(f"[blue]URL:[/blue] {data['url']}")
        print(f"  [green]Name:[/green] {data.get('name', 'N/A')}")
        print(f"  [green]Discount:[/green] {data['discount']}")
        print(f"  [green]Price:[/green] €{data.get('price', 'N/A')}")
        print(f"  [green]Barcode:[/green] {data['barcode']}")
        print()

    context.close()
    browser.close()

    return product_data, product_promotion_from, product_promotion_to


def send_to_api(product_data: list, promotion_from: str, promotion_to: str, api_url: str = "http://localhost:8081"):
    """
    Send scraped product data to the API.

    Args:
        product_data: List of products with url, discount, and barcode
        promotion_from: Start date of promotion (e.g. "29/1")
        promotion_to: End date of promotion (e.g. "4/2")
        api_url: Base URL of the API
    """
    endpoint = f"{api_url}/products/batch-upload-colruyt"

    payload = {
        "products": [
            {
                "url": item["url"],
                "name": item.get("name"),
                "discount": item["discount"],
                "barcode": item["barcode"],
                "price": item.get("price")
            }
            for item in product_data
        ],
        "promotion_from": promotion_from,
        "promotion_to": promotion_to
    }

    print(f"\n[bold yellow]Sending {len(product_data)} products to API...[/bold yellow]")
    print(f"[cyan]Endpoint: {endpoint}[/cyan]")
    print(f"[cyan]Promotion period: {promotion_from} - {promotion_to}[/cyan]")

    try:
        response = requests.post(endpoint, json=payload, timeout=60)
        response.raise_for_status()

        result = response.json()

        print(f"\n[bold green]========================================[/bold green]")
        print(f"[bold green]API RESPONSE[/bold green]")
        print(f"[bold green]========================================[/bold green]")
        print(f"[green]Status: {result.get('status')}[/green]")
        print(f"[green]Total processed: {result.get('total')}[/green]")
        print(f"[green]Matched in OpenFoodFacts: {result.get('matched')}[/green]")
        print(f"[yellow]Not found in OpenFoodFacts: {result.get('not_found')}[/yellow]")
        print(f"[red]Errors: {result.get('errors')}[/red]")

        return result

    except requests.exceptions.ConnectionError:
        print(f"[bold red]ERROR: Could not connect to API at {api_url}[/bold red]")
        print(f"[red]Make sure the backend server is running![/red]")
        return None
    except requests.exceptions.Timeout:
        print(f"[bold red]ERROR: API request timed out[/bold red]")
        return None
    except requests.exceptions.HTTPError as e:
        print(f"[bold red]ERROR: API returned error: {e}[/bold red]")
        return None
    except Exception as e:
        print(f"[bold red]ERROR: {e}[/bold red]")
        return None


if __name__ == "__main__":
    with sync_playwright() as playwright:
        product_data, promotion_from, promotion_to = run(playwright)

        # Send to API if we have valid products
        if product_data:
            send_to_api(product_data, promotion_from, promotion_to)
        else:
            print(f"\n[yellow]No valid products to send to API[/yellow]")

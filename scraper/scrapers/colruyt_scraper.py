from playwright.sync_api import sync_playwright, Playwright
from rich import print
from bs4 import BeautifulSoup
import re
import random
import time


def run(playwright: Playwright):
    chrome = playwright.chromium

    # Launch browser with explicit args to avoid bot detection
    browser = chrome.launch(
        headless=False,
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
        """Scrape a single product for discount and barcode"""
        try:
            print(f"[yellow]Product {product_index}/{total}: {product_url}[/yellow]")

            page_obj.goto(product_url, wait_until="domcontentloaded")
            time.sleep(random.uniform(1.0, 2.0))

            soup = BeautifulSoup(page_obj.content(), "html.parser")

            # Get discount (e.g. "-50%" or "1+1 GRATIS")
            discount = None
            promo_div = soup.find("div", class_="promos__row--benefits")
            if promo_div:
                # Look for strong tag (for -50% or 1+1 GRATIS)
                strong = promo_div.find("strong")
                if strong:
                    discount = strong.get_text(strip=True)

            # Get link to fic.colruytgroup.com
            barcode = None
            detail_div = soup.find("div", class_="product-detail__product-description-details")
            if detail_div:
                fic_link = detail_div.find("a", href=lambda x: x and "fic.colruytgroup.com" in x)
                if fic_link:
                    fic_url = fic_link.get("href")

                    # Visit fic page to get barcode
                    try:
                        page_obj.goto(fic_url, wait_until="domcontentloaded")
                        time.sleep(random.uniform(0.5, 1.5))

                        fic_soup = BeautifulSoup(page_obj.content(), "html.parser")

                        # Find barcode (GTIN) in span with id="current_gtin"
                        gtin_span = fic_soup.find("span", id="current_gtin")
                        if gtin_span:
                            barcode = gtin_span.get_text(strip=True)

                    except Exception as e:
                        print(f"[red]Error fetching barcode: {e}[/red]")

            return {
                "url": product_url,
                "discount": discount,
                "barcode": barcode
            }

        except Exception as e:
            print(f"[red]Error with product {product_url}: {e}[/red]")
            return {
                "url": product_url,
                "discount": None,
                "barcode": None
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

            # Only add if both discount AND barcode are present
            if result["discount"] and result["barcode"]:
                product_data.append(result)
                print(f"[green]  Discount: {result['discount']} | Barcode: {result['barcode']}[/green]")
            else:
                missing = []
                if not result["discount"]:
                    missing.append("discount")
                if not result["barcode"]:
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
        print(f"  [green]Discount:[/green] {data['discount']}")
        print(f"  [green]Barcode:[/green] {data['barcode']}")
        print()

    context.close()
    browser.close()

    return product_data, product_promotion_from, product_promotion_to



with sync_playwright() as playwright:
    product_full = run(playwright)

from playwright.sync_api import sync_playwright, Playwright
from rich import print
from bs4 import BeautifulSoup
import re
import requests

"""
Scraper for Delhaize promotional products
structure:
- PHASE 1: Parallel page loading to collect all product links
- PHASE 2: Scrape all collected product links with parallel pages

"""


#function to extract date and split in two variables
def parse_promotion_dates(date_string):
    # check if date_string is valid
    if not date_string or date_string == "N/A":
        return "N/A", "N/A"

    # regex pattern:
    # 1. search for 'van '
    # 2. get first date (\d+/\d+/\d+) -> group 1
    # 3. search for ' tot en met '
    # 4. get second date (\d+/\d+/\d+) -> group 2
    pattern = r"van\s+(\d{1,2}/\d{1,2}/\d{4})\s+tot en met\s+(\d{1,2}/\d{1,2}/\d{4})"
    # search in text
    match = re.search(pattern, date_string, re.IGNORECASE)
    if match:
        start_date = match.group(1)
        end_date = match.group(2)
        return start_date, end_date
    else:
        return "N/A", "N/A"


def select_french_language_header(page):
    """Select French language using the header language switcher (persistent for session)."""
    try:
        # Click the language switcher button in header
        switcher_button = page.locator("button[data-testid='header-language-switcher-button']")
        if switcher_button.is_visible(timeout=2000):
            switcher_button.click()
            # Wait for dropdown to appear and click FR option
            page.wait_for_timeout(500)
            fr_option = page.locator("span[data-testid='header-language-switcher-button-label']:has-text('FR')")
            if fr_option.is_visible(timeout=1000):
                fr_option.click()
                page.wait_for_load_state("networkidle")
                print("Language switched to French via header")
                return True
    except Exception as e:
        print(f"Could not switch language: {e}")
    return False



def run(playwright: Playwright):
    # setup browser and navigate to start URL
    start_url = "https://www.delhaize.be/Promolandingpage"
    chrome = playwright.chromium
    browser = chrome.launch(headless=False)

    # Create a shared browser context - all pages will share cookies/state
    context = browser.new_context()
    page = context.new_page()
    page.goto(start_url)
    print(f"Navigated to {start_url}")

    # Handle popups and set language:
    # 1. Language popup (initial - select French)
    try:
        language_button = page.locator("div[data-testid='button-text']:has-text('Français')")
        language_button.click(timeout=5000)
        print("Language popup: French selected")
    except:
        print("Language popup not found or already handled")

    # 2. Cookie popup
    try:
        cookie_button = page.locator("button[data-testid='cookie-popup-accept']")
        cookie_button.click(timeout=5000)
        print("Cookies accepted")
    except:
        print("Cookie popup not found or already handled")

    # Wait for page to stabilize
    page.wait_for_load_state("networkidle")

    # 3. Use header language switcher to ensure French is set (persistent for all pages)
    select_french_language_header(page)

    print("Page loaded, starting to collect product links from all pages...")

    # PHASE 1: Load pages in parallel to collect all product links
    product_urls = set()

    # First, determine how many pages exist
    # We'll check pages until we find an empty one
    MAX_PAGES_TO_CHECK = 1  # for now limit to 1 page for testing
    MAX_CONCURRENT_PAGE_CHECKS = 10  # parallel page loading for discovery

    print("Discovering available pages...")
    page_number = 1
    pages_with_products = []

    # Quick discovery: check pages in batches to find the last page
    while page_number <= MAX_PAGES_TO_CHECK:
        batch_pages = []
        batch_page_numbers = []

        # Open multiple pages at once to check for products
        for offset in range(MAX_CONCURRENT_PAGE_CHECKS):
            current_page_num = page_number + offset
            if current_page_num > MAX_PAGES_TO_CHECK:
                break

            try:
                p = context.new_page()
                page_url = f"{start_url}?pageNumber={current_page_num}"
                batch_pages.append(p)
                batch_page_numbers.append(current_page_num)
                p.goto(page_url, wait_until="domcontentloaded")
            except Exception as e:
                print(f"Error opening page {current_page_num}: {e}")

        # Check each page for products
        found_products_in_batch = False
        for p, page_num in zip(batch_pages, batch_page_numbers):
            try:
                # Wait for product links to appear (or timeout if no products)
                try:
                    p.wait_for_selector("a[data-testid='product-block-image-link']", timeout=15000)
                except:
                    pass  # No products found, will check with .all() below
                links = p.locator("a[data-testid='product-block-image-link']").all()

                if len(links) > 0:
                    pages_with_products.append(page_num)
                    found_products_in_batch = True
                    print(f"Page {page_num}: {len(links)} products found")
                else:
                    print(f"Page {page_num}: No products found")
            except Exception as e:
                print(f"Error checking page {page_num}: {e}")
            finally:
                p.close()

        # If no products found in entire batch, we've reached the end
        if not found_products_in_batch:
            print(f"No more pages with products after page {page_number - 1}")
            break

        page_number += MAX_CONCURRENT_PAGE_CHECKS

    print(f"Found {len(pages_with_products)} pages with products")

    # Now scrape all product links from discovered pages in parallel
    print("Collecting product links from all pages in parallel...")
    MAX_CONCURRENT_PAGES = 5

    for i in range(0, len(pages_with_products), MAX_CONCURRENT_PAGES):
        batch_page_nums = pages_with_products[i:i + MAX_CONCURRENT_PAGES]
        batch_pages = []

        # Open all pages in batch
        for page_num in batch_page_nums:
            try:
                p = context.new_page()
                page_url = f"{start_url}?pageNumber={page_num}"
                batch_pages.append((p, page_num))
                p.goto(page_url, wait_until="domcontentloaded")
            except Exception as e:
                print(f"Error opening page {page_num}: {e}")

        # Collect product links from each page
        for p, page_num in batch_pages:
            try:
                # Wait for product links to appear
                try:
                    p.wait_for_selector("a[data-testid='product-block-image-link']", timeout=15000)
                except:
                    pass  # No products found
                links = p.locator("a[data-testid='product-block-image-link']").all()

                for link in links:
                    url = link.get_attribute("href")
                    if url:
                        if not url.startswith("http"):
                            url = f"https://www.delhaize.be{url}"
                        product_urls.add(url)

                print(f"Page {page_num}: Collected {len(links)} product links (Total: {len(product_urls)})")
            except Exception as e:
                print(f"Error scraping page {page_num}: {e}")
            finally:
                p.close()

    print(f"Total unique product URLs collected: {len(product_urls)}")

    # PHASE 2: Scrape all collected product links with parallel pages
    print(f"\nStarting to scrape {len(product_urls)} products with parallel pages...")

    product_full = []
    MAX_CONCURRENT_PAGES = 5  # number of parallel browser pages
    product_urls_list = list(product_urls)

    # Process products in batches
    for i in range(0, len(product_urls_list), MAX_CONCURRENT_PAGES):
        batch = product_urls_list[i:i + MAX_CONCURRENT_PAGES]
        batch_pages = []

        # Open all pages in the batch simultaneously
        for url in batch:
            try:
                p = context.new_page()
                batch_pages.append((p, url))
                p.goto(url, wait_until="domcontentloaded")
            except Exception as e:
                print(f"Error opening {url}: {e}")

        # Wait for all pages in batch to load and scrape them
        for p, url in batch_pages:
            try:
                # wait for page to be fully loaded in
                p.wait_for_selector("h1[data-testid='product-common-header-title']", timeout=15000)
                # Give a moment for dynamic content to load
                p.wait_for_timeout(1000)

                # extract product details
                soup = BeautifulSoup(p.content(), "html.parser")

                # product name
                product_name = soup.find("h1", {"data-testid": "product-common-header-title"})
                product_name = product_name.text.strip() if product_name else "N/A"

                # Macro nutrient patterns (website loaded in french for better matching with OFF)
                macro_patterns = {
                    "energy_kj": r"Energie",
                    "energy_kcal": r"Kilocalories",
                    "fat": r"Graisses\s+dont",
                    "saturated_fat": r"Graisses\s+Saturées",
                    "carbohydrates": r"Glucides\s+dont",
                    "sugars": r"Sucres",
                    "proteins": r"Protéines",
                    "salt": r"Sel",
                }

                # Extract macro values
                macros = {}
                for macro_name, pattern in macro_patterns.items():
                    label_td = soup.find("td", string=re.compile(pattern, re.IGNORECASE))
                    if label_td:
                        value_td = label_td.find_next_sibling("td")
                        if value_td:
                            # Extract numeric value (e.g. "42 kcal" -> 42.0)
                            value_text = value_td.get_text(strip=True)
                            match = re.search(r"([\d,.]+)", value_text)
                            if match:
                                # Replace comma with dot for float parsing
                                macros[macro_name] = float(match.group(1).replace(",", "."))

                # Skip products without any macro info (likely non-food items or alcohol, ...)
                if not macros:
                    print(f"Skipping (no nutrition info): {product_name}")
                    continue

 

                # promotion info
                product_promotion = soup.find("div", {"data-testid": "tag-promo-label"})
                product_promotion = product_promotion.text.strip() if product_promotion else "N/A"
                # skip online-only promotions
                if product_promotion == "N/A" or re.search(r"online", product_promotion, re.IGNORECASE):
                    print(f"Skipping online-only promo for: {product_name}")
                    continue # go to next product skip this current product

                # promotion date range
                product_promotion_from = "N/A"
                product_promotion_to = "N/A"
                product_promotion_date = soup.find("span", {"data-testid": "tag-promo-expiration-date"})
                if product_promotion_date:
                    product_promotion_date = product_promotion_date.text.strip()
                    product_promotion_from, product_promotion_to = parse_promotion_dates(product_promotion_date)

                # original price
                product_price = "N/A"
                product_original_price = soup.find("div", {"data-testid": "product-block-price"})
                if product_original_price:
                    label_text = product_original_price.get("aria-label")
                    if label_text:
                        match = re.search(r"Prijs:\s+(\d+)\s+euro\s+(\d+)", label_text)
                        if match:
                            product_euros = match.group(1)
                            product_cents = match.group(2)
                            product_price = f"{product_euros}.{product_cents}"

                # store current product details in dict
                current_product = {
                    "name": product_name,
                    "price": product_price,
                    "promotion": product_promotion,
                    "promotion_from": product_promotion_from,
                    "promotion_to": product_promotion_to,
                    "url": url,
                    "macros": macros,  # nutrition info scraped from Delhaize
                    "store_name": "Delhaize"  # Store identifier for backend
                }

                product_full.append(current_product)
                print(f"[{len(product_full)}/{len(product_urls_list)}] Scraped: {product_name}")

            except Exception as e:
                print(f"Error scraping {url}: {e}")
            finally:
                p.close()

        print(f"Batch {i//MAX_CONCURRENT_PAGES + 1} completed. Total scraped: {len(product_full)}")

    print(f"\nScraping completed! Total products scraped: {len(product_full)}")
    print(f"Sample products: {product_full[:3] if len(product_full) >= 3 else product_full}")

    return product_full

with sync_playwright() as playwright:
    product_full = run(playwright)

print("Sending data to API...")
api_url = "http://localhost:8081/products/batch-upload-delhaize"

try:
    # Send data to API (JSON)
    response = requests.post(api_url, json=product_full)
    
    if response.status_code == 200:
        print("Succes!")
    else:
        print(f"error API: {response.status_code} - {response.text}")
except Exception as e:
    print(f"couldn't reach API: {e}")
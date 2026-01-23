from playwright.sync_api import sync_playwright, Playwright
from rich import print
from bs4 import BeautifulSoup
import re
import time # needed for pauzes
import requests

""" 
Scraper for Delhaize promotional products 
structure:
- PHASE 1: Infinite scroll to collect all product links
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



def run(playwright: Playwright):
    # setup browser and navigate to start URL
    start_url = "https://www.delhaize.be/Promolandingpage"
    chrome = playwright.chromium
    browser = chrome.launch(headless=False)
    page = browser.new_page()
    page.goto(start_url)
    print(f"Navigated to {start_url}")

    # before opening products, there are two popups to handle:
    # 1. language popup (Nederlands)
    try:
        language_button = page.locator("div[data-testid='button-text']:has-text('Nederlands')")
        language_button.click(timeout=5000)
        print("Language selected: Nederlands")
    except:
        print("Language popup not found or already handled")

    # 2. cookie popup
    try:
        cookie_button = page.locator("button[data-testid='cookie-popup-accept']")
        cookie_button.click(timeout=5000)
        print("Cookies accepted")
    except:
        print("Cookie popup not found or already handled")

    # Wait for page to stabilize
    page.wait_for_load_state("networkidle")
    print("Page loaded, starting infinite scroll to collect all product links...")

    # PHASE 1: Scroll incrementally and collect all unique product links
    # set to store unique product URLs
    product_urls = set()

    # track how many times we've seen the same number of products
    no_new_products_count = 0
    max_no_new_products = 5  # stop after 5 consecutive scrolls without new products

    scroll_pause_time = 2  # seconds to wait after each scroll

    scroll_limit = 5
    scroll_count = 0
    while scroll_limit > scroll_count:
        previous_count = len(product_urls)

        # collect all product links currently visible on the page
        links = page.locator("a[data-testid='product-block-image-link']").all()
        for link in links:
            url = link.get_attribute("href")
            if url:
                # make sure URL is absolute
                if not url.startswith("http"):
                    url = f"https://www.delhaize.be{url}"
                product_urls.add(url)

        new_count = len(product_urls)
        new_products = new_count - previous_count

        print(f"Collected {new_count} unique product links (+{new_products} new)...")

        # Check if we got new products
        if new_products == 0:
            no_new_products_count += 1
            print(f"No new products found ({no_new_products_count}/{max_no_new_products})...")

            if no_new_products_count >= max_no_new_products:
                print(f"Einde van de pagina bereikt. Total unique products: {len(product_urls)}")
                break
        else:
            # reset counter if we found new products
            no_new_products_count = 0

        # INCREMENTAL SCROLL: scroll by viewport height instead of to absolute bottom
        # this keeps products in view and prevents virtual scrolling from removing them
        page.evaluate("window.scrollBy(0, window.innerHeight)")

        # wait for new products to load
        time.sleep(scroll_pause_time)

        # check if we're near the bottom of the page
        at_bottom = page.evaluate("""
            () => {
                return (window.innerHeight + window.scrollY) >= document.body.scrollHeight - 100;
            }
        """)

        if at_bottom:
            print("Reached near bottom of page, scrolling a bit more to trigger lazy loading...")
            # scroll a bit more to trigger any remaining lazy loading
            page.evaluate("window.scrollBy(0, 500)")
            time.sleep(scroll_pause_time)
        scroll_count += 1

    # PHASE 2: Scrape all collected product links with parallel pages
    print(f"\nStarting to scrape {len(product_urls)} products with parallel pages...")

    product_full = []
    MAX_CONCURRENT_PAGES = 10  # number of parallel browser pages
    product_urls_list = list(product_urls)

    # Process products in batches
    for i in range(0, len(product_urls_list), MAX_CONCURRENT_PAGES):
        batch = product_urls_list[i:i + MAX_CONCURRENT_PAGES]
        batch_pages = []

        # Open all pages in the batch simultaneously
        for url in batch:
            try:
                p = browser.new_page()
                batch_pages.append((p, url))
                p.goto(url, wait_until="domcontentloaded")
            except Exception as e:
                print(f"Error opening {url}: {e}")

        # Wait for all pages in batch to load and scrape them
        for p, url in batch_pages:
            try:
                # wait for page to be fully loaded in
                p.wait_for_selector("h1[data-testid='product-common-header-title']", timeout=10000)
                p.wait_for_load_state("networkidle")

                # extract product details
                soup = BeautifulSoup(p.content(), "html.parser")

                # product name
                product_name = soup.find("h1", {"data-testid": "product-common-header-title"})
                product_name = product_name.text.strip() if product_name else "N/A"

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
                    "url": url
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
api_url = "http://localhost:8000/products/batch-upload-delhaize"

try:
    # Send data to API (JSON)
    response = requests.post(api_url, json=product_full)
    
    if response.status_code == 200:
        print("Succes!")
    else:
        print(f"error API: {response.status_code} - {response.text}")
except Exception as e:
    print(f"couldn't reach API: {e}")
from playwright.sync_api import sync_playwright, Playwright
from rich import print
from bs4 import BeautifulSoup
import re

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
    print("Page loaded, starting product scraping...")

    # get product promotion info
    while True:
        # open every product in a new page because all details are not available on the listing page
        for link in page.locator("a[data-testid='product-block-image-link']").all():
            p = browser.new_page(base_url="https://www.delhaize.be/") # href doesnt contain ful url ==> add base url
            url = link.get_attribute("href")
            if url is not None:
                p.goto(url)
                print(f"Opened product page: {url}")

                # wait for page to be fully loaded in
                p.wait_for_selector("h1[data-testid='product-common-header-title']", timeout=10000)

                # ensure all network activity is done so that dynamic content is fully loaded
                p.wait_for_load_state("networkidle")

                # extract product details
                soup = BeautifulSoup(p.content(), "html.parser")
                # product name
                product_name = soup.find("h1", {"data-testid": "product-common-header-title"})
                # check if name exist
                if product_name:
                    product_name = product_name.text.strip()
                else:
                    product_name = "N/A"

                # promotion info
                product_promotion = soup.find("div", {"data-testid": "tag-promo-label"})
                # check if promotion exist
                if product_promotion:
                    product_promotion = product_promotion.text.strip()
                else:
                    product_promotion = "N/A"
                    
                # promotion date range
                product_promotion_date = soup.find("span", {"data-testid": "tag-promo-expiration-date"})
                if product_promotion_date:
                    product_promotion_date = product_promotion_date.text.strip()
                    # extract from and to dates
                    product_promotion_from, product_promotion_to = parse_promotion_dates(product_promotion_date)
                else:
                    product_promotion_date = "N/A"

                print(f"Product Name: {product_name}")
                print(f"Product Promotion: {product_promotion}")
                print(f"Product Promotion Date: {product_promotion_date}")
                print(f"Product Promotion From: {product_promotion_from}")
                print(f"Product Promotion To: {product_promotion_to}")

            else:
                p.close()
                print(f"URL doesnt exist, closed page.")
        
            p.close() # close the last opened product page


with sync_playwright() as playwright:
    run(playwright)
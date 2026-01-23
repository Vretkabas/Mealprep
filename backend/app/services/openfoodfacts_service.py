import requests


# Het product via de barcode ophalen
def get_product_by_barcode(barcode: str) -> dict | None:
    try:
        response = requests.get(f"https://world.openfoodfacts.org/api/v2/product/{barcode}.json", timeout=5)
        if response.status_code != 200:
            return None
        # haal de gegevens van het product uit de json
        data = response.json()
        product = data.get("product")
        if not product:
            return None

        nutriments = product.get("nutriments", {})
        # geef de waardes mee
        return {
            "barcode": barcode,
            "name": product.get("product_name"),
            "brands": product.get("brands"),
            "nutriments": {
                "energy_kcal": nutriments.get("energy-kcal_100g"),
                "proteins": nutriments.get("proteins_100g"),
                "carbohydrates": nutriments.get("carbohydrates_100g"),
                "fat": nutriments.get("fat_100g"),
                "sugars": nutriments.get("sugars_100g"),
                "salt": nutriments.get("salt_100g"),
            }
        }
    except Exception as e:
        print("Fout bij ophalen product:", e)
        return None

from google import genai
import json
import os

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

SYSTEM_PROMPT = """Je bent een data-processor voor een Belgische voedingsapp.
Ik geef je een lijst met producten (naam, korting-tekst, originele prijs).

Voor elk product, geef een JSON object terug met:
- clean_name: Leesbare productnaam. Behoud verpakkingsinfo die het product uniek maakt (bv. "Bak 24x25cl", "Blik 6x33cl", "1kg", "6-pack"). Verwijder alleen rommel zoals "promo", "actie", speciale tekens. Voorbeelden:
  - "Jupiler Pils Bak 24x25cl" → "Jupiler Pils Bak 24x25cl"
  - "Jupiler Pils Blik 6x33cl" → "Jupiler Pils Blik 6x33cl"
  - "PROMO Coca-Cola 1.5L" → "Coca-Cola 1.5L"
  - "Boni Selection Wraps" → "Boni Selection Wraps"
- category: Kies uit [  'Groenten', 'Fruit', 'Vlees_Vis_Vega', 'Zuivel', 'Koolhydraten','Pantry','Snacks','Drinken', 'Huishouden','Overig']
- primary_macro: Kies uit [Protein, Carbs, Fat, Balanced, None]
- is_healthy: Boolean (true/false)
- promo_price: Bereken de effectieve promotieprijs per stuk op basis van de korting en originele prijs.
  Regels:
  - Eenvoudige % korting (bv. "-20%", "30% KORTING"): promo_price = originele_prijs * (1 - pct/100), afgerond op 2 decimalen.
  - "1+1 GRATIS" of "2de GRATIS": je betaalt 1 stuk maar krijgt er 2 → effectieve prijs per stuk = originele_prijs / 2.
  - "2+1 GRATIS": je betaalt 2 maar krijgt er 3 → effectieve prijs per stuk = (originele_prijs * 2) / 3.
  - "3+2 GRATIS": je betaalt 3 maar krijgt er 5 → effectieve prijs per stuk = (originele_prijs * 3) / 5.
  - "2de aan -X%" of "2de aan X%": je betaalt 1 vol + 1 aan (1-X/100) → effectieve prijs per stuk = originele_prijs * (2 - X/100) / 2.
  - "2de aan halve prijs": effectieve prijs per stuk = originele_prijs * 0.75.
  - Als de originele prijs null/onbekend is, of de korting is niet rekenbaar: geef null terug.
  Geef het resultaat als een getal (float) of null. Geen tekst, geen euro-teken.

Antwoord ALLEEN met een JSON array. Geen uitleg."""


async def enrich_products(product_names: list[str], discounts: list[str] = None, prices: list[float] = None) -> list[dict]:
    """
    Stuur een batch productnamen naar Gemini voor categorisatie en promo-prijs berekening.
    Returns list of {clean_name, category, primary_macro, is_healthy, promo_price}
    """
    if not product_names:
        return []

    # Build enriched input: list of {name, discount, price}
    items = []
    for i, name in enumerate(product_names):
        items.append({
            "name": name,
            "discount": discounts[i] if discounts and i < len(discounts) else None,
            "original_price": prices[i] if prices and i < len(prices) else None,
        })

    prompt = f"""Verwerk deze {len(items)} producten:

{json.dumps(items, ensure_ascii=False)}

Geef exact {len(items)} JSON objecten terug in een array."""

    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config={
                "system_instruction": SYSTEM_PROMPT,
                "response_mime_type": "application/json",
            },
        )

        results = json.loads(response.text)

        # Validate that we got the right number of results
        if len(results) != len(product_names):
            print(f"WARNING: Gemini returned {len(results)} results for {len(product_names)} products")
            # Pad or truncate to match input length
            while len(results) < len(product_names):
                results.append({"clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False, "promo_price": None})
            results = results[:len(product_names)]

        return results

    except Exception as e:
        print(f"ERROR: Gemini enrichment failed: {e}")
        # Return safe defaults so the pipeline doesn't break
        return [
            {"clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False, "promo_price": None}
            for _ in product_names
        ]


async def enrich_products_batched(product_names: list[str], discounts: list[str] = None, prices: list[float] = None, batch_size: int = 20) -> list[dict]:
    """
    Enrich products in batches to stay within Gemini token limits.
    Returns list of enrichments in same order as input.
    """
    all_results = []

    for i in range(0, len(product_names), batch_size):
        batch_names = product_names[i:i + batch_size]
        batch_discounts = discounts[i:i + batch_size] if discounts else None
        batch_prices = prices[i:i + batch_size] if prices else None
        print(f"  Gemini batch {i // batch_size + 1}: enriching {len(batch_names)} products...")
        batch_results = await enrich_products(batch_names, batch_discounts, batch_prices)
        all_results.extend(batch_results)

    return all_results

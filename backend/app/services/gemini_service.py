from google import genai
import json
import os
import asyncio

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
  - "N+M GRATIS" algemeen: je betaalt N maar krijgt er N+M → effectieve prijs per stuk = (originele_prijs * N) / (N + M).
  - "2de aan -X%" of "2de aan X%": je betaalt 1 vol + 1 aan (1-X/100) → effectieve prijs per stuk = originele_prijs * (2 - X/100) / 2.
  - "2de aan halve prijs": effectieve prijs per stuk = originele_prijs * 0.75.
  - "-X% VANAF N ST" of "X% VANAF N ST": korting van X% geldig vanaf N stuks → promo_price = originele_prijs * (1 - X/100).
  - Als de originele prijs null/onbekend is, of de korting is niet rekenbaar: geef null terug.
  Geef het resultaat als een getal (float) of null. Geen tekst, geen euro-teken.
- is_meerdere_artikels: Boolean. true als de promotie meerdere artikels vereist (bv. "1+1 GRATIS", "2de aan -25%", "-40% VANAF 6 ST"), false voor enkelvoudige kortingen (bv. "-20%").
- deal_quantity: Integer. Het totaal aantal stuks in één volledige deal.
  Regels:
  - Eenvoudige % korting (geen "VANAF"): deal_quantity = 1.
  - "N+M GRATIS": deal_quantity = N + M. (bv. "1+1 GRATIS" → 2, "6+6 GRATIS" → 12, "2+1 GRATIS" → 3).
  - "2de aan -X%", "2de aan halve prijs", "2de GRATIS": deal_quantity = 2.
  - "-X% VANAF N ST": deal_quantity = N. (bv. "-40% VANAF 6 ST" → 6, "-35% VANAF 2 ST" → 2).

Antwoord ALLEEN met een JSON array. Geen uitleg."""


_GEMINI_DEFAULT = {"clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False, "promo_price": None, "is_meerdere_artikels": False, "deal_quantity": 1}


async def enrich_products(product_names: list[str], discounts: list[str] = None, prices: list[float] = None, max_retries: int = 2) -> list[dict]:
    """
    Stuur een batch productnamen naar Gemini voor categorisatie en promo-prijs berekening.
    Returns list of {clean_name, category, primary_macro, is_healthy, promo_price, is_meerdere_artikels, deal_quantity}
    Retries up to max_retries times with a short delay on failure.
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

    for attempt in range(max_retries + 1):
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
                while len(results) < len(product_names):
                    results.append({**_GEMINI_DEFAULT})
                results = results[:len(product_names)]

            return results

        except Exception as e:
            if attempt < max_retries:
                wait = 3 * (attempt + 1)
                print(f"WARNING: Gemini attempt {attempt + 1}/{max_retries + 1} failed: {e}. Retrying in {wait}s...")
                await asyncio.sleep(wait)
            else:
                print(f"ERROR: Gemini enrichment failed after {max_retries + 1} attempts: {e}")

    return [{**_GEMINI_DEFAULT} for _ in product_names]


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

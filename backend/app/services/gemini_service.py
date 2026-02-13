from google import genai
import json
import os

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))

SYSTEM_PROMPT = """Je bent een data-processor voor een Belgische voedingsapp.
Ik geef je een lijst met ruwe productnamen van een supermarkt.

Voor elk product, geef een JSON object terug met:
- clean_name: Nette naam (zonder "6x33cl", "promo", gewicht-info)
- category: Kies uit [Groenten, Fruit, Vlees/Vis, Zuivel, Koolhydraten, Snacks/Snoep, Drinken, Overig]
- primary_macro: Kies uit [Protein, Carbs, Fat, Balanced, None]
- is_healthy: Boolean (true/false)

Antwoord ALLEEN met een JSON array. Geen uitleg."""


async def enrich_products(product_names: list[str]) -> list[dict]:
    """
    Stuur een batch productnamen naar Gemini voor categorisatie.
    Returns list of {clean_name, category, primary_macro, is_healthy}
    """
    if not product_names:
        return []

    prompt = f"""Categoriseer deze {len(product_names)} producten:

{json.dumps(product_names, ensure_ascii=False)}

Geef exact {len(product_names)} JSON objecten terug in een array."""

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
                results.append({"clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False})
            results = results[:len(product_names)]

        return results

    except Exception as e:
        print(f"ERROR: Gemini enrichment failed: {e}")
        # Return safe defaults so the pipeline doesn't break
        return [
            {"clean_name": None, "category": "Overig", "primary_macro": "None", "is_healthy": False}
            for _ in product_names
        ]


async def enrich_products_batched(product_names: list[str], batch_size: int = 20) -> list[dict]:
    """
    Enrich products in batches to stay within Gemini token limits.
    Returns list of enrichments in same order as input.
    """
    all_results = []

    for i in range(0, len(product_names), batch_size):
        batch = product_names[i:i + batch_size]
        print(f"  Gemini batch {i // batch_size + 1}: enriching {len(batch)} products...")
        batch_results = await enrich_products(batch)
        all_results.extend(batch_results)

    return all_results

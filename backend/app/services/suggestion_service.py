from google import genai
import json
import os
from typing import Optional
from app.services.database_service import get_database_service
from app.services.user_services import get_user_settings

client = genai.Client(api_key=os.getenv("GEMINI_API_KEY"))


def _build_user_context(settings: dict) -> str:
    """Zet user settings om naar leesbare tekst voor de Gemini prompt."""
    lines = []

    goal_map = {"lose": "afvallen", "maintain": "gewicht behouden", "gain": "bijkomen"}
    goal = goal_map.get(settings.get("goal", ""), settings.get("goal", "onbekend"))
    lines.append(f"- Doel: {goal}")

    if settings.get("daily_calorie_target"):
        lines.append(f"- Dagelijks caloriedoel: {settings['daily_calorie_target']} kcal")

    if settings.get("daily_protein_target"):
        lines.append(f"- Dagelijks eiwitdoel: {settings['daily_protein_target']}g")

    if settings.get("allergens"):
        allergens = ", ".join(settings["allergens"])
        lines.append(f"- Allergieën: {allergens}")

    if settings.get("dietary_type"):
        lines.append(f"- Dieet: {settings['dietary_type']}")

    if settings.get("health_goals"):
        goals = ", ".join(settings["health_goals"])
        lines.append(f"- Gezondheidsdoelen: {goals}")

    if settings.get("persons_count"):
        lines.append(f"- Koken voor: {settings['persons_count']} personen")

    if settings.get("budget_weekly"):
        lines.append(f"- Weekbudget: €{settings['budget_weekly']}")

    return "\n".join(lines) if lines else "- Geen specifieke voorkeuren"


def _build_promotions_context(promotions: list[dict]) -> str:
    """Zet lijst van promoties om naar leesbare tekst voor de Gemini prompt."""
    if not promotions:
        return "Geen actieve promoties gevonden."

    lines = []
    for p in promotions:
        name = p.get("product_name", "?")
        discount = p.get("discount_percentage", "")
        promo_price = p.get("promo_price")
        category = p.get("category", "")
        is_healthy = p.get("is_healthy", False)

        line = f"- {name}"
        if discount:
            line += f": {discount}"
        if promo_price:
            line += f" → €{promo_price:.2f}"
        if category:
            line += f" ({category})"
        if is_healthy:
            line += " ✓gezond"
        lines.append(line)

    return "\n".join(lines)


async def generate_promotion_suggestions(
    scanned_products: list[str],
    user_id: str,
    store_name: str,
) -> dict:
    """
    Hoofdfunctie: bouw prompt op en vraag Gemini om suggesties.

    Returns dict met:
    - suggestions: lijst van aanbevolen promotieproducten
    - meal_tip: korte maaltijdtip van Gemini
    """

    # get user settings for context
    settings = await get_user_settings(user_id)
    user_context = _build_user_context(settings) if settings else "- Geen gebruikersinstellingen beschikbaar"

    # get active promotions for store
    db = await get_database_service()
    promotions = await db.get_active_promotions_by_store_name(store_name)
    promotions_context = _build_promotions_context(promotions)

    # build prompt
    scanned_list = "\n".join(f"- {p}" for p in scanned_products)

    prompt = f"""Je bent een slimme meal prep assistent voor een Belgische gebruiker.

GEBRUIKERSPROFIEL:
{user_context}

PRODUCTEN IN WINKELMANDJE:
{scanned_list}

HUIDIGE PROMOTIES BIJ {store_name.upper()}:
{promotions_context}

TAAK:
Suggereer MAX 5 producten die goed passen bij het winkelmandje van de gebruiker:

1. Geef VOORKEUR aan producten die momenteel in promotie zijn bij {store_name} (uit de lijst hierboven)
2. Als er geen relevante promoties zijn voor een belangrijk ontbrekend ingrediënt, suggereer dan gerust een product ZONDER promotie. Vermeld dan duidelijk dat het geen promotie is maar wel een goede aanvulling. Voorbeeld: "Kip is geen promotie, maar past perfect bij je pasta en groenten op basis van je eiwitdoel."
3. Producten moeten goed combineren met de producten in het winkelmandje (qua recept/maaltijd)
4. Passen bij het doel en allergieën van de gebruiker
5. Bij voorkeur gezond (tenzij het doel anders is)
6. Binnen het budget passen indien opgegeven

Geef ook een korte praktische meal tip (max 2 zinnen) over hoe alles gecombineerd kan worden tot een maaltijd.

Antwoord UITSLUITEND in dit JSON formaat:
{{
  "suggestions": [
    {{
      "product_name": "naam van het product",
      "reason": "korte reden waarom dit past (max 1 zin)",
      "discount_label": "bv. -30% of 1+1 GRATIS (null als geen promotie)",
      "promo_price": 1.89,
      "category": "categorie",
      "is_healthy": true,
      "is_promotion": true
    }}
  ],
  "meal_tip": "Korte tip over hoe je dit kunt combineren."
}}"""

    # Gemini API call
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=prompt,
            config={
                "response_mime_type": "application/json",
            },
        )

        result = json.loads(response.text)

        # validation 
        if "suggestions" not in result:
            result["suggestions"] = []
        if "meal_tip" not in result:
            result["meal_tip"] = ""

        return result

    except Exception as e:
        print(f"ERROR: Gemini suggestion failed: {e}")
        return {
            "suggestions": [],
            "meal_tip": "",
            "error": str(e),
        }

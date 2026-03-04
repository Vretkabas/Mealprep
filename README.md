# MealPrep - Smart Grocery & Meal Planning App

Een mobiele applicatie die gebruikers helpt om slimmer boodschappen te doen door **promoties**, **voedingswaarden** en **AI-gestuurde maaltijdsuggesties** te combineren. Scan producten, bouw boodschappenlijsten en bespaar geld met actuele supermarktaanbiedingen.

---

## Inhoudsopgave

- [Quick Start](#quick-start)
- [Tech Stack](#tech-stack)
- [Projectstructuur](#projectstructuur)
- [Backend](#backend)
- [Frontend (Flutter)](#frontend-flutter)
- [Scraper](#scraper)
- [Infrastructuur](#infrastructuur)
- [API Endpoints](#api-endpoints)
- [Database Schema](#database-schema)
- [Belangrijke Functies](#belangrijke-functies)
- [Authenticatie](#authenticatie)
- [Externe Services](#externe-services)
- [Bronnen & Documentatie](#bronnen--documentatie)

---

## Quick Start

### Vereisten

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.7+)
- [Android Studio](https://developer.android.com/studio) (voor Android emulator)
- Een `.env` bestand in de root met de juiste credentials (zie hieronder)

### 1. Repository clonen

```bash
git clone <repository-url>
cd Mealprep
```

### 2. Environment variabelen instellen

Maak een `.env` bestand aan in de root:

```env
DATABASE_URL=postgresql://<user>:<password>@<host>:5432/<database>
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_KEY=<supabase-anon-key>
GEMINI_API_KEY=<google-gemini-api-key>
```

En in `frontend/mealprep_flutter/.env`:

```env
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_KEY=<supabase-anon-key>
```

### 3. Backend starten (Docker)

```bash
docker-compose up --build
```

Dit start:
| Service | Poort | Beschrijving |
|---------|-------|--------------|
| Backend (FastAPI) | `8000` | REST API |
| Nginx | `8081` | Reverse proxy met CORS |
| Redis | `6379` | Caching |
| Scraper | - | Idle container, handmatig uitvoerbaar |

### 4. Flutter app starten

```bash
cd frontend/mealprep_flutter
flutter pub get
flutter run
```

> **Android emulator:** De app gebruikt automatisch `http://10.0.2.2:8081` als base URL (Android emulator host bridge). Voor web/iOS wordt `http://localhost:8081` gebruikt.

### 5. Backend zonder Docker (optioneel)

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

## Tech Stack

### Backend
| Technologie | Versie | Gebruik |
|-------------|--------|---------|
| **Python** | 3.11+ | Programmeertaal |
| **FastAPI** | 0.109.0 | REST API framework |
| **Uvicorn** | - | ASGI server |
| **AsyncPG** | - | Async PostgreSQL driver |
| **Supabase** | - | Database (PostgreSQL) & authenticatie |
| **Google Gemini** | gemini-2.5-flash | AI product-enrichment & suggesties |
| **Redis** | - | Caching |
| **SQLite** | - | Lokale OpenFoodFacts cache |

### Frontend
| Technologie | Gebruik |
|-------------|---------|
| **Flutter** (Dart) | Cross-platform mobiel framework |
| **Riverpod** | State management |
| **Dio** | HTTP client |
| **Supabase Flutter** | Authenticatie & real-time |
| **mobile_scanner** | Barcode scanning |
| **fl_chart** | Voedingswaarde grafieken |
| **easy_localization** | Meertaligheid |

### Scraper
| Technologie | Gebruik |
|-------------|---------|
| **Playwright** | Headless browser automation |
| **BeautifulSoup** | HTML parsing |

### Infrastructuur
| Technologie | Gebruik |
|-------------|---------|
| **Docker Compose** | Orchestratie van alle services |
| **Nginx** | Reverse proxy, CORS-afhandeling |

---

## Projectstructuur

```
Mealprep/
│
├── backend/                          # Python FastAPI backend
│   ├── app/
│   │   ├── main.py                  # FastAPI app entry point, middleware config
│   │   ├── auth.py                  # JWT validatie via Supabase JWKS
│   │   ├── supabase_client.py       # Supabase client initialisatie
│   │   │
│   │   ├── routers/                 # API route handlers
│   │   │   ├── products.py          # Product CRUD, zoeken, promoties, batch-upload
│   │   │   ├── barcode_api.py       # Barcode lookup via OpenFoodFacts DB
│   │   │   ├── user.py              # Gebruikersinstellingen & voorkeuren
│   │   │   ├── shopping_lists.py    # Boodschappenlijsten beheer
│   │   │   ├── suggestions.py       # AI maaltijdsuggesties
│   │   │   └── favorites_router.py  # Favoriete producten
│   │   │
│   │   ├── services/                # Business logic laag
│   │   │   ├── database_service.py  # AsyncPG connection pool & queries
│   │   │   ├── product_service.py   # OpenFoodFacts SQLite lookups
│   │   │   ├── gemini_service.py    # Google Gemini AI integratie
│   │   │   ├── openfoodfacts_service.py  # Barcode scan logging
│   │   │   ├── user_services.py     # BMR berekening, calorie targets
│   │   │   ├── shopping_list_service.py  # Boodschappenlijst logica
│   │   │   ├── suggestion_service.py     # AI suggestie generatie
│   │   │   └── favorites_service.py # Favorieten CRUD
│   │   │
│   │   ├── data/
│   │   │   └── openfoodfacts.db     # SQLite cache met product voedingsdata
│   │   │
│   │   └── scripts/                 # Utility scripts
│   │
│   ├── requirements.txt             # Python dependencies
│   └── Dockerfile
│
├── frontend/mealprep_flutter/       # Flutter mobiele app
│   ├── lib/
│   │   ├── main.dart               # App entry point, Supabase init, routing
│   │   ├── login_page.dart         # Login scherm
│   │   ├── register_page.dart      # Registratie scherm
│   │   ├── home_page.dart          # Dashboard met navigatie
│   │   ├── product_catalog_page.dart  # Product catalogus & zoeken
│   │   ├── store_selection_page.dart  # Winkelselectie
│   │   │
│   │   ├── quick_setup/            # Onboarding wizard (4 stappen)
│   │   │   ├── quick_setup_page1.dart  # Gezondheidsdoelen
│   │   │   ├── quick_setup_page2.dart  # Lichaamsgegevens
│   │   │   ├── quick_setup_page3.dart  # Allergieën & dieet
│   │   │   └── quick_setup_page4.dart  # Aantal personen
│   │   │
│   │   ├── screens/                # Feature schermen
│   │   │   ├── barcode_scanner_screen.dart  # Barcode scanner
│   │   │   ├── camera_scan_screen.dart      # Camera scan
│   │   │   ├── product_screen.dart          # Product detail
│   │   │   └── object_scan_screen.dart      # Object herkenning
│   │   │
│   │   ├── ShoppingList/           # Boodschappenlijst UI
│   │   ├── settings/               # Profiel & instellingen
│   │   ├── favorites/              # Favorieten pagina
│   │   │
│   │   ├── services/               # API communicatie
│   │   │   ├── food_api_service.dart       # Product API calls
│   │   │   ├── shopping_list_service.dart  # Boodschappenlijst API
│   │   │   ├── suggestion_service.dart     # Suggesties API
│   │   │   ├── favorites_service.dart      # Favorieten API
│   │   │   ├── user_service.dart           # User settings API
│   │   │   └── scanned_item_service.dart   # Scan logging
│   │   │
│   │   └── config/                 # Configuratie bestanden
│   │
│   ├── pubspec.yaml               # Flutter dependencies
│   ├── .env                       # Frontend environment variabelen
│   └── assets/images/             # Winkel logo's (Colruyt, Delhaize, etc.)
│
├── scraper/                        # Web scraper voor promoties
│   ├── scrapers/
│   │   ├── colruyt_scraper.py     # Colruyt promoties & producten scrapen
│   │   ├── delhaize_scraper.py    # Delhaize scraper
│   │   └── colruyt_all_products.py  # Alle Colruyt producten ophalen
│   ├── database/
│   │   └── connection.py          # Database connectie voor scraper
│   └── Dockerfile
│
├── nginx/
│   └── nginx.conf                 # Reverse proxy configuratie
│
├── docker-compose.yml             # Stack orchestratie
├── .env                           # Root environment variabelen
└── README.md
```

---

## Backend

### Entry Point (`app/main.py`)

Configureert de FastAPI applicatie met:
- CORS middleware (alle origins toegestaan voor ontwikkeling)
- Router registratie voor alle modules
- Database connection pool initialisatie bij startup
- Cleanup bij shutdown

### Authenticatie (`app/auth.py`)

JWT-validatie via Supabase:
- Haalt JWKS (JSON Web Key Set) op van Supabase
- Cached keys, herlaadt bij key rotation
- Valideert ES256 (ECDSA) signatures
- Extraheert `user_id` uit het `sub` claim

### Services

| Service | Bestand | Verantwoordelijkheid |
|---------|---------|---------------------|
| **DatabaseService** | `database_service.py` | AsyncPG connection pool, alle database queries (products, stores, promotions, shopping lists) |
| **ProductService** | `product_service.py` | Zoeken in lokale OpenFoodFacts SQLite DB op barcode of naam |
| **GeminiService** | `gemini_service.py` | Batch AI-enrichment van producten (categorie, macro focus, gezondheid, promoprijs) |
| **SuggestionService** | `suggestion_service.py` | AI maaltijdsuggesties op basis van winkelwagen, voorkeuren en promoties |
| **UserServices** | `user_services.py` | BMR-berekening (Mifflin-St Jeor), dagelijkse calorie/eiwit targets |
| **ShoppingListService** | `shopping_list_service.py` | Boodschappenlijst CRUD, prijs- en besparingsberekening |
| **FavoritesService** | `favorites_service.py` | Favoriete producten beheer |
| **OpenFoodFactsService** | `openfoodfacts_service.py` | Barcode scan logging met deduplicatie (24u window) |

---

## Frontend (Flutter)

### App Flow

1. **Login/Register** - Supabase authenticatie
2. **Quick Setup** (eerste keer) - 4-stappen onboarding wizard
   - Gezondheidsdoel kiezen (afvallen/behouden/aankomen)
   - Lichaamsgegevens invoeren (leeftijd, lengte, gewicht, geslacht, activiteitsniveau)
   - Allergieën & dieetvoorkeuren
   - Aantal personen waarvoor je kookt
3. **Home Dashboard** - Navigatie naar alle features
4. **Winkelselectie** - Kies je supermarkt (Colruyt, Delhaize, etc.)
5. **Product Catalogus** - Zoeken, bladeren, filteren
6. **Barcode Scanner** - Scan producten met camera
7. **Boodschappenlijsten** - Maak lijsten, voeg items toe, bekijk totalen
8. **Favorieten** - Sla veelgebruikte producten op
9. **AI Suggesties** - Krijg slimme aanbevelingen op basis van je winkelwagen

### Services (API communicatie)

Elke service in `lib/services/` correspondeert met een backend router en handelt HTTP-requests af via Dio. Ze bevatten methodes voor alle CRUD-operaties en verwerken de responses naar Dart objecten.

---

## Scraper

### Colruyt Scraper (`scrapers/colruyt_scraper.py`)

Automatische web scraper voor Colruyt promoties:

1. **Playwright** opent headless Chromium met bot-detectie bypass
2. Navigeert naar Colruyt promotie pagina's
3. **BeautifulSoup** parsed de HTML voor:
   - Product URL's, namen, barcodes
   - Kortingslabels (bijv. "2+1 GRATIS", "-30%", "2de aan halve prijs")
   - Prijzen en promo-datums
4. Filtert op voedingsgerelateerde categorieën
5. Stuurt data naar de backend via `/products/batch-upload-colruyt`

### Batch Upload Flow

Wanneer de scraper data naar de backend stuurt:

1. Barcodes worden gematcht tegen de OpenFoodFacts SQLite database
2. Productnamen worden in batches (20 per keer) naar Gemini gestuurd voor enrichment
3. Gemini retourneert: categorie, macro focus, gezondheidsrating, berekende promoprijs
4. Producten en promoties worden opgeslagen in Supabase

---

## Infrastructuur

### Docker Compose

```yaml
Services:
  backend    → FastAPI op poort 8000
  nginx      → Reverse proxy op poort 8081 → backend:8000
  redis      → Cache op poort 6379
  scraper    → Idle container, handmatig te starten
```

### Nginx

- Proxied alle requests naar de backend
- Voegt CORS headers toe voor cross-origin requests
- 300s timeout voor batch operaties (scraper uploads)
- Behandelt preflight OPTIONS requests

---

## API Endpoints

### Products (`/products`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `GET` | `/products` | Lijst producten (optioneel: `store`, `limit`) |
| `GET` | `/products/search?q=...&store_name=...` | Zoek producten op naam (max 500 resultaten) |
| `GET` | `/products/promotions?store_name=...` | Actieve promoties per winkel |
| `POST` | `/products/batch-upload-colruyt` | Batch import vanuit scraper met AI enrichment |
| `GET` | `/proxy/image?url=...` | Image proxy voor cross-domain afbeeldingen |

### Barcode (`/food`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `GET` | `/food/barcode/{barcode}` | Product opzoeken op barcode (vereist JWT) |

### Boodschappenlijsten (`/shopping-lists`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `POST` | `/shopping-lists` | Nieuwe lijst aanmaken |
| `GET` | `/shopping-lists` | Alle lijsten van gebruiker |
| `GET` | `/shopping-lists/{list_id}/items` | Items in een lijst met productdetails |
| `POST` | `/shopping-lists/{list_id}/items/by-barcode` | Item toevoegen via barcode |
| `POST` | `/shopping-lists/items/{item_id}/update` | Hoeveelheid/checked status updaten |
| `DELETE` | `/shopping-lists/items/{item_id}` | Item verwijderen |
| `DELETE` | `/shopping-lists/{list_id}` | Lijst verwijderen |

### Suggesties (`/suggestions`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `POST` | `/suggestions/promotions` | AI maaltijdsuggesties op basis van winkelwagen & profiel |

### Favorieten (`/favorites`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `GET` | `/favorites` | Favoriete producten ophalen |
| `POST` | `/favorites` | Product toevoegen aan favorieten |
| `DELETE` | `/favorites/{product_id}` | Product verwijderen uit favorieten |
| `GET` | `/favorites/{product_id}/check` | Controleer of product favoriet is |

### Gebruiker (`/user`)

| Methode | Endpoint | Beschrijving |
|---------|----------|--------------|
| `POST` | `/user/preferences` | Gebruikersinstellingen opslaan |
| `GET` | `/user/settings` | Gebruikersinstellingen ophalen |

---

## Database Schema

### Supabase (PostgreSQL)

#### `user_settings`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `user_id` | UUID (PK) | Supabase auth user ID |
| `goal` | text | lose / maintain / gain |
| `daily_calorie_target` | int | Berekend via Mifflin-St Jeor |
| `daily_protein_target` | int | Berekend op basis van doel |
| `allergens` | text[] | Lijst van allergieën |
| `age`, `height`, `weight_current` | int/float | Lichaamsgegevens |
| `gender`, `activity_level` | text | Profiel parameters |
| `total_savings` | float | Totale besparingen bijgehouden |

#### `products`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `product_id` | UUID (PK) | Uniek product ID |
| `barcode` | text (unique) | EAN barcode |
| `product_name` | text | Productnaam |
| `brand` | text | Merk |
| `energy_kcal` | float | Calorieën |
| `proteins_g`, `carbohydrates_g`, `fat_g` | float | Macronutriënten |
| `sugars_g`, `fiber_g`, `salt_g` | float | Overige voedingswaarden |
| `nutriscore_grade` | text | Nutri-Score (A-E) |
| `image_url` | text | Product afbeelding |
| `price` | float | Reguliere prijs |
| `colruyt_category` | text | AI-verrijkte categorie |

#### `promotions`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `promo_id` | UUID (PK) | Uniek promotie ID |
| `store_id` | UUID (FK) | Verwijzing naar winkel |
| `product_id` | UUID (FK) | Verwijzing naar product |
| `discount_label` | text | Origineel label ("2+1 GRATIS") |
| `original_price` | float | Prijs zonder korting |
| `promo_price` | float | Berekende promotieprijs |
| `valid_from`, `valid_until` | date | Geldigheidsperiode |
| `category` | text | AI-verrijkte categorie |
| `primary_macro` | text | Protein / Carbs / Fat / Balanced |
| `is_healthy` | boolean | AI gezondheidsrating |
| `is_meerdere_artikels` | boolean | Multi-unit deal vlag |
| `deal_quantity` | int | Aantal stuks per deal |
| `is_active` | boolean | Momenteel actief |

#### `shopping_lists`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `list_id` | UUID (PK) | Uniek lijst ID |
| `user_id` | UUID (FK) | Eigenaar |
| `list_name` | text | Naam van de lijst |
| `status` | text | active / archived |
| `estimated_total_price` | float | Berekende totaalprijs |
| `estimated_savings` | float | Berekende besparing |

#### `shopping_list_items`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `item_id` | UUID (PK) | Uniek item ID |
| `list_id` | UUID (FK) | Verwijzing naar lijst |
| `product_id` | UUID (FK) | Verwijzing naar product |
| `quantity` | int | Aantal |
| `is_checked` | boolean | Afgevinkt in de lijst |
| `has_promo` | boolean | Heeft actieve promotie |
| `promo_id` | UUID (FK, nullable) | Verwijzing naar promotie |

#### `user_favorites`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `favorite_id` | UUID (PK) | Uniek ID |
| `user_id` | UUID (FK) | Eigenaar |
| `product_id` | UUID (FK) | Favoriet product |

#### `scanned_items`
| Kolom | Type | Beschrijving |
|-------|------|--------------|
| `barcode` | text | Gescande barcode |
| `user_id` | UUID | Gebruiker |
| `scan_mode` | text | barcode / camera / object |
| `scanned_at` | timestamp | Tijdstip van scan |

### SQLite (`openfoodfacts.db`)

Lokale cache van OpenFoodFacts productdata voor snelle barcode lookups zonder externe API calls.

---

## Belangrijke Functies

### Promotie Parsing

Het systeem verwerkt complexe Belgische supermarkt kortingslabels:

| Label | Logica |
|-------|--------|
| `-30%` | Simpele procentuele korting |
| `1+1 GRATIS` | Koop 1, krijg 1 gratis (50% korting per stuk) |
| `2+1 GRATIS` | Koop 2, krijg 1 gratis (33% korting per stuk) |
| `3+2 GRATIS` | Koop 3, krijg 2 gratis (40% korting per stuk) |
| `2de aan halve prijs` | Tweede artikel 50% korting |
| `2de aan -70%` | Tweede artikel 70% korting |
| `-40% VANAF 6 ST` | 40% korting bij aankoop van 6+ stuks |

### Multi-Unit Promo Berekening

Bij multi-unit deals wordt de prijs correct berekend op basis van volledige groepen:

```
Voorbeeld: "2+1 GRATIS" bij prijs €3.00, hoeveelheid = 5
- Volledige groepen: 5 ÷ 3 = 1 groep (3 stuks)
- Resterende: 5 % 3 = 2 stuks
- Totaal: (1 × 3 × €2.00) + (2 × €3.00) = €12.00
- Besparing: 1 × 3 × (€3.00 - €2.00) = €3.00
```

### BMR & Calorie Berekening

Gebruikt de **Mifflin-St Jeor** formule:
- Man: `BMR = 10 × gewicht(kg) + 6.25 × lengte(cm) - 5 × leeftijd - 5`
- Vrouw: `BMR = 10 × gewicht(kg) + 6.25 × lengte(cm) - 5 × leeftijd - 161`

Vermenigvuldigd met activiteitsfactor en aangepast op basis van doel (afvallen: -500 kcal, aankomen: +500 kcal).

### AI Product Enrichment

Google Gemini verrijkt gescrapete producten in batches:
- **Categorie**: Zuivel, Vlees, Groenten, etc.
- **Primary Macro**: Protein / Carbs / Fat / Balanced
- **Is Healthy**: Boolean gezondheidsrating
- **Promo Price**: Berekende promotieprijs op basis van kortingslabel
- **Deal Quantity**: Aantal stuks per promotiedeal

### AI Maaltijdsuggesties

Op basis van de winkelwagen, gebruikersprofiel en actieve promoties genereert Gemini:
- Tot 5 aanbevolen aanvullende producten
- Maaltijdtip met recept/combinatie suggestie
- Rekening houdend met allergieën en gezondheidsdoelen

---

## Authenticatie

**Flow:**

```
Flutter App                    Supabase                    FastAPI Backend
    │                             │                             │
    ├── Sign up / Login ──────────►                             │
    │                             │                             │
    ◄── JWT access token ─────────┤                             │
    │                             │                             │
    ├── API request + Bearer token ─────────────────────────────►
    │                             │                             │
    │                             │   ◄── Fetch JWKS ───────────┤
    │                             │   ──── Public keys ─────────►
    │                             │                             │
    │                             │        Validate ES256 JWT   │
    │                             │        Extract user_id      │
    │                             │                             │
    ◄──────────────────────────── Response ─────────────────────┤
```

- **Algoritme**: ES256 (ECDSA)
- **Key management**: JWKS endpoint met automatische key rotation
- **Audience claim**: "authenticated"

---

## Externe Services

| Service | Gebruik |
|---------|---------|
| [Supabase](https://supabase.com) | PostgreSQL database & JWT authenticatie |
| [Google Gemini API](https://ai.google.dev/) | AI product enrichment & maaltijdsuggesties |
| [OpenFoodFacts](https://world.openfoodfacts.org/) | Voedingswaarden & barcode lookups |
| [Colruyt GCS Bucket](https://github.com/BelgianNoise/colruyt-products-scraper) | Colruyt productdata (via BelgianNoise) |

---

## Bronnen & Documentatie

### Backend
- [Supabase PostgreSQL Setup](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [FastAPI Documentatie](https://fastapi.tiangolo.com/)
- [Mifflin-St Jeor Formule](https://reference.medscape.com/calculator/846/mifflin-st-jeor-equation)

### Frontend
- [Flutter Installatie](https://docs.flutter.dev/install/quick)
- [Android SDK Setup](https://developer.android.com/about/versions/11/setup-sdk)
- [Flutter + Supabase](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Supabase Flutter Auth](https://supabase.com/blog/flutter-authentication)

### Barcode & Producten
- [OpenFoodFacts API](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorial-off-api/)
- [mobile_scanner package](https://pub.dev/packages/mobile_scanner)
- [fl_chart package](https://pub.dev/packages/fl_chart)

### Scraper
- [Web Scraping Tutorial](https://www.youtube.com/watch?v=E4wU8y7r1Uc)
- [BeautifulSoup Guide](https://realpython.com/beautiful-soup-web-scraper-python/)
- [Colruyt Products Scraper (BelgianNoise)](https://github.com/BelgianNoise/colruyt-products-scraper)

### Privacy
- [GDPR Compliance](https://gdpr.eu/tag/gdpr/)

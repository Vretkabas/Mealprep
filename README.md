# MealPrep - Smart Grocery & Meal Planning App

> **Language / Taal:**
> - [Nederlands](#-nederlands)
> - [English](#-english)

---

<a id="-nederlands"></a>

# Nederlands

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

---
---

<a id="-english"></a>

# English

A mobile application that helps users shop smarter by combining **promotions**, **nutritional data** and **AI-powered meal suggestions**. Scan products, build shopping lists and save money with real-time supermarket deals.

---

## Table of Contents

- [Quick Start](#quick-start-en)
- [Tech Stack](#tech-stack-en)
- [Project Structure](#project-structure)
- [Backend](#backend-en)
- [Frontend (Flutter)](#frontend-flutter-en)
- [Scraper](#scraper-en)
- [Infrastructure](#infrastructure)
- [API Endpoints](#api-endpoints-en)
- [Database Schema](#database-schema-en)
- [Key Features](#key-features)
- [Authentication](#authentication)
- [External Services](#external-services)
- [References & Documentation](#references--documentation)

---

<a id="quick-start-en"></a>

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) & Docker Compose
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10.7+)
- [Android Studio](https://developer.android.com/studio) (for Android emulator)
- A `.env` file in the root with the correct credentials (see below)

### 1. Clone the repository

```bash
git clone <repository-url>
cd Mealprep
```

### 2. Set up environment variables

Create a `.env` file in the root:

```env
DATABASE_URL=postgresql://<user>:<password>@<host>:5432/<database>
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_KEY=<supabase-anon-key>
GEMINI_API_KEY=<google-gemini-api-key>
```

And in `frontend/mealprep_flutter/.env`:

```env
SUPABASE_URL=https://<project-id>.supabase.co
SUPABASE_KEY=<supabase-anon-key>
```

### 3. Start the backend (Docker)

```bash
docker-compose up --build
```

This starts:
| Service | Port | Description |
|---------|------|-------------|
| Backend (FastAPI) | `8000` | REST API |
| Nginx | `8081` | Reverse proxy with CORS |
| Redis | `6379` | Caching |
| Scraper | - | Idle container, run manually |

### 4. Start the Flutter app

```bash
cd frontend/mealprep_flutter
flutter pub get
flutter run
```

> **Android emulator:** The app automatically uses `http://10.0.2.2:8081` as the base URL (Android emulator host bridge). For web/iOS it uses `http://localhost:8081`.

### 5. Backend without Docker (optional)

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

---

<a id="tech-stack-en"></a>

## Tech Stack

### Backend
| Technology | Version | Purpose |
|------------|---------|---------|
| **Python** | 3.11+ | Programming language |
| **FastAPI** | 0.109.0 | REST API framework |
| **Uvicorn** | - | ASGI server |
| **AsyncPG** | - | Async PostgreSQL driver |
| **Supabase** | - | Database (PostgreSQL) & authentication |
| **Google Gemini** | gemini-2.5-flash | AI product enrichment & suggestions |
| **Redis** | - | Caching |
| **SQLite** | - | Local OpenFoodFacts cache |

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter** (Dart) | Cross-platform mobile framework |
| **Riverpod** | State management |
| **Dio** | HTTP client |
| **Supabase Flutter** | Authentication & real-time |
| **mobile_scanner** | Barcode scanning |
| **fl_chart** | Nutritional data charts |
| **easy_localization** | Multi-language support |

### Scraper
| Technology | Purpose |
|------------|---------|
| **Playwright** | Headless browser automation |
| **BeautifulSoup** | HTML parsing |

### Infrastructure
| Technology | Purpose |
|------------|---------|
| **Docker Compose** | Orchestration of all services |
| **Nginx** | Reverse proxy, CORS handling |

---

## Project Structure

```
Mealprep/
│
├── backend/                          # Python FastAPI backend
│   ├── app/
│   │   ├── main.py                  # FastAPI app entry point, middleware config
│   │   ├── auth.py                  # JWT validation via Supabase JWKS
│   │   ├── supabase_client.py       # Supabase client initialization
│   │   │
│   │   ├── routers/                 # API route handlers
│   │   │   ├── products.py          # Product CRUD, search, promotions, batch upload
│   │   │   ├── barcode_api.py       # Barcode lookup via OpenFoodFacts DB
│   │   │   ├── user.py              # User settings & preferences
│   │   │   ├── shopping_lists.py    # Shopping list management
│   │   │   ├── suggestions.py       # AI meal suggestions
│   │   │   └── favorites_router.py  # Favorite products
│   │   │
│   │   ├── services/                # Business logic layer
│   │   │   ├── database_service.py  # AsyncPG connection pool & queries
│   │   │   ├── product_service.py   # OpenFoodFacts SQLite lookups
│   │   │   ├── gemini_service.py    # Google Gemini AI integration
│   │   │   ├── openfoodfacts_service.py  # Barcode scan logging
│   │   │   ├── user_services.py     # BMR calculation, calorie targets
│   │   │   ├── shopping_list_service.py  # Shopping list logic
│   │   │   ├── suggestion_service.py     # AI suggestion generation
│   │   │   └── favorites_service.py # Favorites CRUD
│   │   │
│   │   ├── data/
│   │   │   └── openfoodfacts.db     # SQLite cache with product nutrition data
│   │   │
│   │   └── scripts/                 # Utility scripts
│   │
│   ├── requirements.txt             # Python dependencies
│   └── Dockerfile
│
├── frontend/mealprep_flutter/       # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart               # App entry point, Supabase init, routing
│   │   ├── login_page.dart         # Login screen
│   │   ├── register_page.dart      # Registration screen
│   │   ├── home_page.dart          # Dashboard with navigation
│   │   ├── product_catalog_page.dart  # Product catalog & search
│   │   ├── store_selection_page.dart  # Store selection
│   │   │
│   │   ├── quick_setup/            # Onboarding wizard (4 steps)
│   │   │   ├── quick_setup_page1.dart  # Health goals
│   │   │   ├── quick_setup_page2.dart  # Body measurements
│   │   │   ├── quick_setup_page3.dart  # Allergies & diet
│   │   │   └── quick_setup_page4.dart  # Number of people
│   │   │
│   │   ├── screens/                # Feature screens
│   │   │   ├── barcode_scanner_screen.dart  # Barcode scanner
│   │   │   ├── camera_scan_screen.dart      # Camera scan
│   │   │   ├── product_screen.dart          # Product detail
│   │   │   └── object_scan_screen.dart      # Object recognition
│   │   │
│   │   ├── ShoppingList/           # Shopping list UI
│   │   ├── settings/               # Profile & settings
│   │   ├── favorites/              # Favorites page
│   │   │
│   │   ├── services/               # API communication
│   │   │   ├── food_api_service.dart       # Product API calls
│   │   │   ├── shopping_list_service.dart  # Shopping list API
│   │   │   ├── suggestion_service.dart     # Suggestions API
│   │   │   ├── favorites_service.dart      # Favorites API
│   │   │   ├── user_service.dart           # User settings API
│   │   │   └── scanned_item_service.dart   # Scan logging
│   │   │
│   │   └── config/                 # Configuration files
│   │
│   ├── pubspec.yaml               # Flutter dependencies
│   ├── .env                       # Frontend environment variables
│   └── assets/images/             # Store logos (Colruyt, Delhaize, etc.)
│
├── scraper/                        # Web scraper for promotions
│   ├── scrapers/
│   │   ├── colruyt_scraper.py     # Colruyt promotions & products scraping
│   │   ├── delhaize_scraper.py    # Delhaize scraper
│   │   └── colruyt_all_products.py  # Fetch all Colruyt products
│   ├── database/
│   │   └── connection.py          # Database connection for scraper
│   └── Dockerfile
│
├── nginx/
│   └── nginx.conf                 # Reverse proxy configuration
│
├── docker-compose.yml             # Stack orchestration
├── .env                           # Root environment variables
└── README.md
```

---

<a id="backend-en"></a>

## Backend

### Entry Point (`app/main.py`)

Configures the FastAPI application with:
- CORS middleware (all origins allowed for development)
- Router registration for all modules
- Database connection pool initialization at startup
- Cleanup at shutdown

### Authentication (`app/auth.py`)

JWT validation via Supabase:
- Fetches JWKS (JSON Web Key Set) from Supabase
- Caches keys, reloads on key rotation
- Validates ES256 (ECDSA) signatures
- Extracts `user_id` from the `sub` claim

### Services

| Service | File | Responsibility |
|---------|------|----------------|
| **DatabaseService** | `database_service.py` | AsyncPG connection pool, all database queries (products, stores, promotions, shopping lists) |
| **ProductService** | `product_service.py` | Search local OpenFoodFacts SQLite DB by barcode or name |
| **GeminiService** | `gemini_service.py` | Batch AI enrichment of products (category, macro focus, healthiness, promo price) |
| **SuggestionService** | `suggestion_service.py` | AI meal suggestions based on cart, preferences and promotions |
| **UserServices** | `user_services.py` | BMR calculation (Mifflin-St Jeor), daily calorie/protein targets |
| **ShoppingListService** | `shopping_list_service.py` | Shopping list CRUD, price & savings calculation |
| **FavoritesService** | `favorites_service.py` | Favorite products management |
| **OpenFoodFactsService** | `openfoodfacts_service.py` | Barcode scan logging with deduplication (24h window) |

---

<a id="frontend-flutter-en"></a>

## Frontend (Flutter)

### App Flow

1. **Login/Register** - Supabase authentication
2. **Quick Setup** (first time) - 4-step onboarding wizard
   - Choose health goal (lose/maintain/gain weight)
   - Enter body measurements (age, height, weight, gender, activity level)
   - Allergies & dietary preferences
   - Number of people you cook for
3. **Home Dashboard** - Navigation to all features
4. **Store Selection** - Choose your supermarket (Colruyt, Delhaize, etc.)
5. **Product Catalog** - Search, browse, filter
6. **Barcode Scanner** - Scan products with camera
7. **Shopping Lists** - Create lists, add items, view totals
8. **Favorites** - Save frequently used products
9. **AI Suggestions** - Get smart recommendations based on your cart

### Services (API communication)

Each service in `lib/services/` corresponds to a backend router and handles HTTP requests via Dio. They contain methods for all CRUD operations and parse responses into Dart objects.

---

<a id="scraper-en"></a>

## Scraper

### Colruyt Scraper (`scrapers/colruyt_scraper.py`)

Automated web scraper for Colruyt promotions:

1. **Playwright** opens headless Chromium with bot detection bypass
2. Navigates to Colruyt promotion pages
3. **BeautifulSoup** parses the HTML for:
   - Product URLs, names, barcodes
   - Discount labels (e.g. "2+1 GRATIS", "-30%", "2de aan halve prijs")
   - Prices and promotion dates
4. Filters for food-related categories only
5. Sends data to the backend via `/products/batch-upload-colruyt`

### Batch Upload Flow

When the scraper sends data to the backend:

1. Barcodes are matched against the OpenFoodFacts SQLite database
2. Product names are sent to Gemini in batches (20 at a time) for enrichment
3. Gemini returns: category, macro focus, healthiness rating, calculated promo price
4. Products and promotions are saved to Supabase

---

## Infrastructure

### Docker Compose

```yaml
Services:
  backend    → FastAPI on port 8000
  nginx      → Reverse proxy on port 8081 → backend:8000
  redis      → Cache on port 6379
  scraper    → Idle container, start manually
```

### Nginx

- Proxies all requests to the backend
- Adds CORS headers for cross-origin requests
- 300s timeout for batch operations (scraper uploads)
- Handles preflight OPTIONS requests

---

<a id="api-endpoints-en"></a>

## API Endpoints

### Products (`/products`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/products` | List products (optional: `store`, `limit`) |
| `GET` | `/products/search?q=...&store_name=...` | Search products by name (max 500 results) |
| `GET` | `/products/promotions?store_name=...` | Active promotions per store |
| `POST` | `/products/batch-upload-colruyt` | Batch import from scraper with AI enrichment |
| `GET` | `/proxy/image?url=...` | Image proxy for cross-domain images |

### Barcode (`/food`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/food/barcode/{barcode}` | Look up product by barcode (requires JWT) |

### Shopping Lists (`/shopping-lists`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/shopping-lists` | Create new list |
| `GET` | `/shopping-lists` | All lists for the user |
| `GET` | `/shopping-lists/{list_id}/items` | Items in a list with product details |
| `POST` | `/shopping-lists/{list_id}/items/by-barcode` | Add item by barcode |
| `POST` | `/shopping-lists/items/{item_id}/update` | Update quantity/checked status |
| `DELETE` | `/shopping-lists/items/{item_id}` | Remove item |
| `DELETE` | `/shopping-lists/{list_id}` | Delete entire list |

### Suggestions (`/suggestions`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/suggestions/promotions` | AI meal suggestions based on cart & profile |

### Favorites (`/favorites`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/favorites` | Get favorite products |
| `POST` | `/favorites` | Add product to favorites |
| `DELETE` | `/favorites/{product_id}` | Remove product from favorites |
| `GET` | `/favorites/{product_id}/check` | Check if product is favorited |

### User (`/user`)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/user/preferences` | Save user settings |
| `GET` | `/user/settings` | Get user settings |

---

<a id="database-schema-en"></a>

## Database Schema

### Supabase (PostgreSQL)

#### `user_settings`
| Column | Type | Description |
|--------|------|-------------|
| `user_id` | UUID (PK) | Supabase auth user ID |
| `goal` | text | lose / maintain / gain |
| `daily_calorie_target` | int | Calculated via Mifflin-St Jeor |
| `daily_protein_target` | int | Calculated based on goal |
| `allergens` | text[] | List of allergies |
| `age`, `height`, `weight_current` | int/float | Body measurements |
| `gender`, `activity_level` | text | Profile parameters |
| `total_savings` | float | Accumulated savings tracker |

#### `products`
| Column | Type | Description |
|--------|------|-------------|
| `product_id` | UUID (PK) | Unique product ID |
| `barcode` | text (unique) | EAN barcode |
| `product_name` | text | Product name |
| `brand` | text | Brand |
| `energy_kcal` | float | Calories |
| `proteins_g`, `carbohydrates_g`, `fat_g` | float | Macronutrients |
| `sugars_g`, `fiber_g`, `salt_g` | float | Other nutritional values |
| `nutriscore_grade` | text | Nutri-Score (A-E) |
| `image_url` | text | Product image |
| `price` | float | Regular price |
| `colruyt_category` | text | AI-enriched category |

#### `promotions`
| Column | Type | Description |
|--------|------|-------------|
| `promo_id` | UUID (PK) | Unique promotion ID |
| `store_id` | UUID (FK) | Reference to store |
| `product_id` | UUID (FK) | Reference to product |
| `discount_label` | text | Original label ("2+1 GRATIS") |
| `original_price` | float | Price without discount |
| `promo_price` | float | Calculated promotion price |
| `valid_from`, `valid_until` | date | Validity period |
| `category` | text | AI-enriched category |
| `primary_macro` | text | Protein / Carbs / Fat / Balanced |
| `is_healthy` | boolean | AI healthiness rating |
| `is_meerdere_artikels` | boolean | Multi-unit deal flag |
| `deal_quantity` | int | Units per deal |
| `is_active` | boolean | Currently active |

#### `shopping_lists`
| Column | Type | Description |
|--------|------|-------------|
| `list_id` | UUID (PK) | Unique list ID |
| `user_id` | UUID (FK) | Owner |
| `list_name` | text | Name of the list |
| `status` | text | active / archived |
| `estimated_total_price` | float | Calculated total price |
| `estimated_savings` | float | Calculated savings |

#### `shopping_list_items`
| Column | Type | Description |
|--------|------|-------------|
| `item_id` | UUID (PK) | Unique item ID |
| `list_id` | UUID (FK) | Reference to list |
| `product_id` | UUID (FK) | Reference to product |
| `quantity` | int | Amount |
| `is_checked` | boolean | Checked off in the list |
| `has_promo` | boolean | Has active promotion |
| `promo_id` | UUID (FK, nullable) | Reference to promotion |

#### `user_favorites`
| Column | Type | Description |
|--------|------|-------------|
| `favorite_id` | UUID (PK) | Unique ID |
| `user_id` | UUID (FK) | Owner |
| `product_id` | UUID (FK) | Favorite product |

#### `scanned_items`
| Column | Type | Description |
|--------|------|-------------|
| `barcode` | text | Scanned barcode |
| `user_id` | UUID | User |
| `scan_mode` | text | barcode / camera / object |
| `scanned_at` | timestamp | Time of scan |

### SQLite (`openfoodfacts.db`)

Local cache of OpenFoodFacts product data for fast barcode lookups without external API calls.

---

## Key Features

### Promotion Parsing

The system processes complex Belgian supermarket discount labels:

| Label | Logic |
|-------|-------|
| `-30%` | Simple percentage discount |
| `1+1 GRATIS` | Buy 1, get 1 free (50% discount per unit) |
| `2+1 GRATIS` | Buy 2, get 1 free (33% discount per unit) |
| `3+2 GRATIS` | Buy 3, get 2 free (40% discount per unit) |
| `2de aan halve prijs` | Second item at half price |
| `2de aan -70%` | Second item at 70% off |
| `-40% VANAF 6 ST` | 40% discount when buying 6+ units |

### Multi-Unit Promo Calculation

For multi-unit deals, the price is correctly calculated based on complete groups:

```
Example: "2+1 GRATIS" at price €3.00, quantity = 5
- Complete groups: 5 ÷ 3 = 1 group (3 units)
- Remaining: 5 % 3 = 2 units
- Total: (1 × 3 × €2.00) + (2 × €3.00) = €12.00
- Savings: 1 × 3 × (€3.00 - €2.00) = €3.00
```

### BMR & Calorie Calculation

Uses the **Mifflin-St Jeor** formula:
- Male: `BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 5`
- Female: `BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age - 161`

Multiplied by activity factor and adjusted based on goal (lose weight: -500 kcal, gain weight: +500 kcal).

### AI Product Enrichment

Google Gemini enriches scraped products in batches:
- **Category**: Dairy, Meat, Vegetables, etc.
- **Primary Macro**: Protein / Carbs / Fat / Balanced
- **Is Healthy**: Boolean healthiness rating
- **Promo Price**: Calculated promotion price based on discount label
- **Deal Quantity**: Number of units per promotion deal

### AI Meal Suggestions

Based on the shopping cart, user profile and active promotions, Gemini generates:
- Up to 5 recommended complementary products
- Meal tip with recipe/combination suggestion
- Taking into account allergies and health goals

---

## Authentication

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

- **Algorithm**: ES256 (ECDSA)
- **Key management**: JWKS endpoint with automatic key rotation
- **Audience claim**: "authenticated"

---

## External Services

| Service | Purpose |
|---------|---------|
| [Supabase](https://supabase.com) | PostgreSQL database & JWT authentication |
| [Google Gemini API](https://ai.google.dev/) | AI product enrichment & meal suggestions |
| [OpenFoodFacts](https://world.openfoodfacts.org/) | Nutritional data & barcode lookups |
| [Colruyt GCS Bucket](https://github.com/BelgianNoise/colruyt-products-scraper) | Colruyt product data (via BelgianNoise) |

---

## References & Documentation

### Backend
- [Supabase PostgreSQL Setup](https://supabase.com/docs/guides/database/connecting-to-postgres)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Mifflin-St Jeor Formula](https://reference.medscape.com/calculator/846/mifflin-st-jeor-equation)

### Frontend
- [Flutter Installation](https://docs.flutter.dev/get-started/install)
- [Android SDK Setup](https://developer.android.com/about/versions/11/setup-sdk)
- [Flutter + Supabase](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter)
- [Supabase Flutter Auth](https://supabase.com/blog/flutter-authentication)

### Barcode & Products
- [OpenFoodFacts API](https://openfoodfacts.github.io/openfoodfacts-server/api/tutorial-off-api/)
- [mobile_scanner package](https://pub.dev/packages/mobile_scanner)
- [fl_chart package](https://pub.dev/packages/fl_chart)

### Scraper
- [Web Scraping Tutorial](https://www.youtube.com/watch?v=E4wU8y7r1Uc)
- [BeautifulSoup Guide](https://realpython.com/beautiful-soup-web-scraper-python/)
- [Colruyt Products Scraper (BelgianNoise)](https://github.com/BelgianNoise/colruyt-products-scraper)

### Privacy
- [GDPR Compliance](https://gdpr.eu/tag/gdpr/)

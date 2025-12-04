flowchart TD
    A[Start: Open App (Real-time mode)] --> B(Scan Barcode met Camera);
    B --> C{Barcode Herkend?};
    
    %% Barcode Recognized Path
    C -- YES --> D(Check Cache/PostgreSQL);
    
    D --> E{In Cache?};
    E -- YES --> F(Retrieve Product Data);
    E -- NO --> G(Call OpenFoodFacts API);
    
    G --> H{Product Gevonden?};
    H -- YES --> F;
    
    %% Object Recognition Path (if Barcode Fails or No Product Found)
    C -- NO --> I[Object Recognition (Gemini Vision)];
    H -- NO --> I;

    I --> J(User Bevestigt Data / Save to Cache);
    J --> F; 

    F --> K[Gemini AI Analysis: Score, Advice, Alternatieven, Promo's];
    K --> L[Toon Resultaat aan Gebruiker];
    L --> M{Add to Shopping List?};
    
    M -- YES --> N[Save to List (shopping_list_items)];
    M -- NO --> O{Scan Meer?};
    
    N --> O;
    O -- YES --> B;
    O -- NO --> P[EINDE];

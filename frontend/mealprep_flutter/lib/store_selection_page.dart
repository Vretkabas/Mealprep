import 'package:flutter/material.dart';
import 'product_catalog_page.dart';

class StoreSelectionPage extends StatelessWidget {
  const StoreSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Voorbeeld lijst van winkels
    final List<Map<String, String>> stores = [
      {'name': 'Delhaize', 'logo': 'assets/delhaize_logo.png'},
      {'name': 'Carrefour', 'logo': 'assets/carrefour_logo.png'},
      {'name': 'Albert Heijn', 'logo': 'assets/ah_logo.png'},
      {'name': 'Jumbo', 'logo': 'assets/jumbo_logo.png'},
      {'name': 'Lidl', 'logo': 'assets/lidl_logo.png'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kies een winkel", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductCatalogPage(storeName: store['name']!),
                  ),
                );
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  // Zorg dat je de logo's lokaal hebt in je assets folder of gebruik placeholders
                  child: Center(
                    child: Text(store['name']!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
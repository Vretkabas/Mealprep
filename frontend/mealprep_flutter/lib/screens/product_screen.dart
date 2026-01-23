import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/food_api_service.dart';

class ProductScreen extends StatefulWidget {
  final String barcode;

  const ProductScreen({super.key, required this.barcode});

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  Map<String, dynamic>? product;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchProduct(); // Hier doen we de API-call
  }

  Future<void> _fetchProduct() async {
    try {
      // Hier haal je de data op van je backend
      final data = await FoodApiService.fetchByBarcode(widget.barcode);

      setState(() {
        product = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Product niet gevonden';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(child: Text(error!)),
      );
    }

    final nutriments = product!['nutriments'] ?? {};

    return Scaffold(
      appBar: AppBar(title: Text(product!['name'] ?? 'Onbekend product')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Barcode: ${product!['barcode']}'),
            Text('Merken: ${product!['brands'] ?? 'Onbekend'}'),
            const SizedBox(height: 16),
            Text('Voedingswaarden per 100g:', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('Energie: ${nutriments['energy_kcal'] ?? '-'} kcal'),
            Text('Eiwitten: ${nutriments['proteins'] ?? '-'} g'),
            Text('Koolhydraten: ${nutriments['carbohydrates'] ?? '-'} g'),
            Text('Vetten: ${nutriments['fat'] ?? '-'} g'),
            Text('Suikers: ${nutriments['sugars'] ?? '-'} g'),
            Text('Zout: ${nutriments['salt'] ?? '-'} g'),
          ],
        ),
      ),
    );
  }
}


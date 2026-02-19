import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/food_api_service.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';

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
    _fetchProduct();
  }
Future<void> _showAddToListSheet() async {
  try {
    final lists = await ShoppingListService.getUserLists();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        if (lists.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("Geen lijsten gevonden"),
          );
        }

        return ListView.builder(
          itemCount: lists.length,
          itemBuilder: (context, index) {
            final list = lists[index];

            return ListTile(
              title: Text(list['list_name']),
              onTap: () async {
                Navigator.pop(context);

                await ShoppingListService.addItemByBarcode(
                  listId: list['list_id'],
                  barcode: widget.barcode,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Product toegevoegd aan lijst"),
                  ),
                );
              },
            );
          },
        );
      },
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Fout: $e")),
    );
  }
}

  Future<void> _fetchProduct() async {
    try {
      // Backend haalt product op en scanned log
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
    // nutrients omzetten naar double
    double proteins = (nutriments['proteins'] ?? 0).toDouble();
    double carbs = (nutriments['carbohydrates'] ?? 0).toDouble();
    double fat = (nutriments['fat'] ?? 0).toDouble();
    double sugars = (nutriments['sugars'] ?? 0).toDouble();
    double salt = (nutriments['salt'] ?? 0).toDouble();

    double total = proteins + carbs + fat + sugars + salt;

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
            const Text(
              'Voedingswaarden per 100g:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Energie: ${nutriments['energy_kcal'] ?? '-'} kcal',
              style: const TextStyle(color: Colors.red),
            ),
            Text(
              'Eiwitten: ${nutriments['proteins'] ?? '-'} g',
              style: const TextStyle(color: Colors.green),
            ),
            Text(
              'Koolhydraten: ${nutriments['carbohydrates'] ?? '-'} g',
              style: const TextStyle(color: Colors.orange),
            ),
            Text(
              'Vetten: ${nutriments['fat'] ?? '-'} g',
              style: const TextStyle(color: Colors.purple),
            ),
            Text(
              'Suikers: ${nutriments['sugars'] ?? '-'} g',
              style: const TextStyle(color: Colors.blue),
            ),
            Text(
              'Zout: ${nutriments['salt'] ?? '-'} g',
              style: const TextStyle(color: Colors.pink),
            ),
            const SizedBox(height: 24),

            if (total > 0)
              SizedBox(
                height: 260,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 40,
                    sections: [
                      _pieSection(proteins, total, Colors.green),
                      _pieSection(carbs, total, Colors.orange),
                      _pieSection(fat, total, Colors.purple),
                      _pieSection(sugars, total, Colors.blue),
                      _pieSection(salt, total, Colors.pink),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _showAddToListSheet,
                icon: const Icon(Icons.playlist_add),
                label: const Text("Toevoegen aan lijst"),
              ),
          ],
        ),
      ),
    );
  }
  }

  PieChartSectionData _pieSection(
    double value,
    double total,
    Color color,
  ) {
    final percentage = (value / total) * 100;

    return PieChartSectionData(
      color: color,
      value: value,
      title: '${percentage.toStringAsFixed(1)}%',
      radius: 60,
      titleStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }
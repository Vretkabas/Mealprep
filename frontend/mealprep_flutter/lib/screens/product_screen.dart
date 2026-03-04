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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          if (lists.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text("Geen lijsten gevonden", textAlign: TextAlign.center),
            );
          }

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Kies een lijst", 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      return ListTile(
                        leading: const Icon(Icons.list_alt, color: Color(0xFF24966D)),
                        title: Text(list['list_name']),
                        onTap: () async {
                          Navigator.pop(context);
                          await ShoppingListService.addItemByBarcode(
                            listId: list['list_id'],
                            barcode: widget.barcode,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Product toegevoegd!")),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fout: $e")));
    }
  }

  Future<void> _fetchProduct() async {
    try {
      final data = await FoodApiService.fetchByBarcode(widget.barcode);
      setState(() {
        product = data;
        loading = false;
      });
    } catch (e) {
      debugPrint('ProductScreen fout (barcode: ${widget.barcode}): $e');
      String message = 'Product niet gevonden';
      final msg = e.toString().toLowerCase();
      if (msg.contains('401') || msg.contains('geautoriseerd') || msg.contains('authenticated')) {
        message = 'Sessie verlopen – log opnieuw in';
      } else if (msg.contains('404') || msg.contains('niet gevonden')) {
        message = 'Product niet gevonden in de database';
      } else if (msg.contains('socket') || msg.contains('connection') || msg.contains('network')) {
        message = 'Geen verbinding met de server';
      }
      setState(() {
        error = message;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF24966D))),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() { loading = true; error = null; });
                    _fetchProduct();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Opnieuw proberen'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF24966D), foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final nutriments = product!['nutriments'] ?? {};
    double proteins = (nutriments['proteins'] ?? 0).toDouble();
    double carbs = (nutriments['carbohydrates'] ?? 0).toDouble();
    double fat = (nutriments['fat'] ?? 0).toDouble();
    double sugars = (nutriments['sugars'] ?? 0).toDouble();
    double salt = (nutriments['salt'] ?? 0).toDouble();
    double total = proteins + carbs + fat;

    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Product Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Stack(
        children: [
          // Decoratieve achtergrond elementen
          Positioned(
            top: -50,
            right: -50,
            child: CircleAvatar(radius: 100, backgroundColor: const Color(0xFF24966D).withOpacity(0.05)),
          ),
          Positioned(
            bottom: 100,
            left: -30,
            child: CircleAvatar(radius: 60, backgroundColor: const Color(0xFF24966D).withOpacity(0.03)),
          ),
          
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 110,
                            height: 110,
                            child: () {
                              final rawUrl = product!['image_url'] as String?;
                              final imageUrl = rawUrl != null
                                  ? '${FoodApiService.baseUrl}/proxy/image?url=${Uri.encodeQueryComponent(rawUrl)}'
                                  : null;
                              if (imageUrl == null) {
                                return const Icon(Icons.fastfood_rounded, size: 50, color: Color(0xFF24966D));
                              }
                              return Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.fastfood_rounded,
                                  size: 50,
                                  color: Color(0xFF24966D),
                                ),
                              );
                            }(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          product!['name'] ?? 'Onbekend product',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          product!['brands'] ?? 'Merk onbekend',
                          style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        ),
                        const Divider(height: 30),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.qr_code_scanner, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(product!['barcode'], style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text("Voedingswaarden per 100g", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),

                  // Nutrition Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      _buildNutriTile("Energie", "${nutriments['energy_kcal'] ?? '-'} kcal", Icons.bolt, Colors.orange),
                      _buildNutriTile("Eiwitten", "${proteins}g", Icons.fitness_center, Colors.green),
                      _buildNutriTile("Koolhydraten", "${carbs}g", Icons.bakery_dining, Colors.blue),
                      _buildNutriTile("Vetten", "${fat}g", Icons.opacity, Colors.purple),
                      _buildNutriTile("Suikers", "${sugars}g", Icons.cake, Colors.red),
                      _buildNutriTile("Zout", "${salt}g", Icons.science, Colors.blueGrey),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Chart Section
                  if (total > 0) ...[
                    const Text("Macro Verdeling", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 4,
                                centerSpaceRadius: 35,
                                sections: [
                                  _pieSection(proteins, total, Colors.green, "Eiwit"),
                                  _pieSection(carbs, total, Colors.blue, "Koolh."),
                                  _pieSection(fat, total, Colors.purple, "Vet"),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildLegend(Colors.green, "Eiwitten"),
                                _buildLegend(Colors.blue, "Koolhydraten"),
                                _buildLegend(Colors.purple, "Vetten"),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 100), // Ruimte voor de knop
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        width: double.infinity,
        height: 60,
        child: ElevatedButton.icon(
          onPressed: _showAddToListSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF24966D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 5,
          ),
          icon: const Icon(Icons.playlist_add),
          label: const Text("TOEVOEGEN AAN LIJST", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ),
    );
  }

  Widget _buildNutriTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        ],
      ),
    );
  }

  PieChartSectionData _pieSection(double value, double total, Color color, String title) {
    final double percentage = (value / total) * 100;
    return PieChartSectionData(
      color: color,
      value: value,
      title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
      radius: 50,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }
}
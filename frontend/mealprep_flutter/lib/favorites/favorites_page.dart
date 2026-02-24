import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/favorites_service.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    try {
      final favorites = await FavoritesService.getFavorites();
      setState(() => _favorites = favorites);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij laden: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String productId, String productName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verwijderen'),
        content: Text('$productName verwijderen uit favorieten?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FavoritesService.removeFavorite(productId);
        await _loadFavorites();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verwijderd uit favorieten')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout: $e')),
        );
      }
    }
  }

  Color _nutriscoreColor(String? grade) {
    switch (grade?.toLowerCase()) {
      case 'a': return Colors.green.shade700;
      case 'b': return Colors.lightGreen;
      case 'c': return Colors.yellow.shade700;
      case 'd': return Colors.orange;
      case 'e': return Colors.red;
      default:  return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn favorieten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFavorites,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Nog geen favorieten',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _favorites.length,
                  itemBuilder: (context, index) {
                    final product = _favorites[index];
                    final productId = product['product_id'] as String;
                    final name = product['product_name'] ?? 'Onbekend';
                    final brand = product['brand'];
                    final kcal = product['energy_kcal'];
                    final proteins = product['proteins_g'];
                    final nutriscore = product['nutriscore_grade'];
                    final imageUrl = product['image_url'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (product['barcode'] != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductScreen(
                                  barcode: product['barcode'],
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              // Product afbeelding
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.white,
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _placeholderIcon(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Product info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (brand != null)
                                      Text(
                                        brand,
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        if (kcal != null)
                                          _infoChip('${kcal.toInt()} kcal',
                                              Colors.orange.shade100),
                                        if (proteins != null) ...[
                                          const SizedBox(width: 6),
                                          _infoChip('${proteins}g eiwit',
                                              Colors.blue.shade100),
                                        ],
                                        if (nutriscore != null) ...[
                                          const SizedBox(width: 6),
                                          _nutriscoreChip(nutriscore),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Verwijder knop
                              IconButton(
                                icon: const Icon(Icons.favorite,
                                    color: Colors.red),
                                onPressed: () =>
                                    _removeFavorite(productId, name),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _placeholderIcon() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.fastfood, color: Colors.grey),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _nutriscoreChip(String grade) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _nutriscoreColor(grade),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Nutriscore ${grade.toUpperCase()}',
        style: const TextStyle(fontSize: 11, color: Colors.white),
      ),
    );
  }
}
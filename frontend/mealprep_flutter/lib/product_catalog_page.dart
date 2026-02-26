import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'ShoppingList/shopping_list_page.dart';
import 'screens/barcode_scanner_screen.dart';

class ProductCatalogPage extends StatefulWidget {
  final String storeName;
  const ProductCatalogPage({super.key, required this.storeName});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  // --- STATE ---
  List<dynamic> _promotions = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showPromoOnly = true; // standaard promoties tonen
  int _selectedIndex = 0;
  int _promoDisplayLimit = 25;
  final TextEditingController _searchController = TextEditingController();

  // --- STYLING ---
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);
  final Color backgroundGrey = const Color(0xFFF5F7F9);

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8081';
    if (Platform.isAndroid) return 'http://10.0.2.2:8081';
    return 'http://localhost:8081';
  }

  @override
  void initState() {
    super.initState();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- PROMOTIES OPHALEN ---
  Future<void> _fetchPromotions() async {
    setState(() => _isLoading = true);
    try {
      final response = await Dio().get(
        '$_baseUrl/products/promotions',
        queryParameters: {'store_name': widget.storeName},
      );
      setState(() {
        _promotions = response.data['promotions'] ?? [];
        _promoDisplayLimit = 25;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Fout bij ophalen promoties: $e");
    }
  }

  // --- ZOEKEN IN ALLE PRODUCTEN ---
  Future<void> _searchProducts(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _showPromoOnly = true;
      });
      return;
    }

    setState(() => _isSearching = true);
    try {
      final response = await Dio().get(
        '$_baseUrl/products/search',
        queryParameters: {
          'q': query,
          'store_name': widget.storeName,
        },
      );
      setState(() {
        _searchResults = response.data['products'] ?? [];
        _showPromoOnly = false;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      print("Zoekfout: $e");
    }
  }

  // --- NAVBAR ---
  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0: Navigator.pushNamed(context, '/home'); break;
      case 1: Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen())); break;
      case 2: Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListsPage())); break;
      case 3: break;
      case 4: Navigator.pushNamed(context, '/profile'); break;
    }
  }

  // --- BUILD ---
  @override
  Widget build(BuildContext context) {
    final List<dynamic> fullList = _showPromoOnly ? _promotions : _searchResults;
    final List<dynamic> displayList = _showPromoOnly
        ? fullList.take(_promoDisplayLimit).toList()
        : fullList;

    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        title: Text(widget.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- ZOEKBALK ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _searchProducts(val),
              decoration: InputDecoration(
                hintText: "Zoek producten bij ${widget.storeName}...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          _searchProducts('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF5F7F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // --- HEADER LABEL ---
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Icon(
                    _showPromoOnly ? Icons.local_offer : Icons.search,
                    size: 16,
                    color: brandGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showPromoOnly
                        ? "${_promotions.length} promoties deze week"
                        : "${_searchResults.length} resultaten gevonden",
                    style: TextStyle(
                      color: textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

          // --- CONTENT ---
          Expanded(
            child: _isLoading || _isSearching
                ? Center(child: CircularProgressIndicator(color: brandGreen))
                : fullList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              _showPromoOnly
                                  ? "Geen promoties gevonden voor ${widget.storeName}"
                                  : "Geen producten gevonden",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.all(12),
                            sliver: SliverGrid(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 0.68,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final item = displayList[index];
                                  return _showPromoOnly
                                      ? _buildPromoCard(item)
                                      : _buildProductCard(item);
                                },
                                childCount: displayList.length,
                              ),
                            ),
                          ),
                          if (_showPromoOnly && _promoDisplayLimit < _promotions.length)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                                child: OutlinedButton(
                                  onPressed: () => setState(() => _promoDisplayLimit += 25),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: brandGreen,
                                    side: BorderSide(color: brandGreen),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    "Meer laden (${_promotions.length - _promoDisplayLimit} resterend)",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: brandGreen,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "Lists"),
          BottomNavigationBarItem(icon: Icon(Icons.star_border), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profile"),
        ],
      ),
    );
  }

  // --- PROMOTIE KAART ---
  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final String name = promo['product_name'] ?? 'Onbekend';
    final String? discount = promo['discount_percentage']; // is discount_label tekst
    final double? promoPrice = promo['promo_price'] != null
        ? double.tryParse(promo['promo_price'].toString())
        : null;
    final double? originalPrice = promo['original_price'] != null
        ? double.tryParse(promo['original_price'].toString())
        : null;
    final String? rawImageUrl = promo['image_url'];
    final String? imageUrl = rawImageUrl != null
        ? '$_baseUrl/proxy/image?url=${Uri.encodeQueryComponent(rawImageUrl)}'
        : null;
    final bool isHealthy = promo['is_healthy'] ?? false;

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Afbeelding + discount badge
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
                        )
                      : const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
                ),
              ),
              // Discount badge
              if (discount != null && discount.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      discount,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              // Gezond badge
              if (isHealthy)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: brandGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (promoPrice != null)
                      Text(
                        "€${promoPrice.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: brandGreen,
                        ),
                      ),
                    const SizedBox(width: 6),
                    if (originalPrice != null)
                      Text(
                        "€${originalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PRODUCT KAART (zoekresultaten) ---
  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['product_name'] ?? 'Onbekend';
    final String? imageUrl = product['image_url'];
    final double? price = product['price'] != null
        ? double.tryParse(product['price'].toString())
        : null;
    final String? content = product['content'];

    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 110,
              width: double.infinity,
              child: imageUrl != null
                  ? Image.network(imageUrl, fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40, color: Colors.grey))
                  : const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (content != null) ...[
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
                const SizedBox(height: 6),
                if (price != null)
                  Text(
                    "€${price.toStringAsFixed(2)}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

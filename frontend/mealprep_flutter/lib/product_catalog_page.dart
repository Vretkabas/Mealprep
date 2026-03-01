import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'ShoppingList/shopping_list_page.dart';
import 'screens/barcode_scanner_screen.dart';

// ── Filter constants ───────────────────────────────────────────────────────────

const List<Map<String, String>> _kCategories = [
  {'key': 'Groenten',       'label': '🥦 Groenten'},
  {'key': 'Fruit',          'label': '🍎 Fruit'},
  {'key': 'Vlees_Vis_Vega', 'label': '🥩 Vlees/Vis/Vega'},
  {'key': 'Zuivel',         'label': '🧀 Zuivel'},
  {'key': 'Koolhydraten',   'label': '🍞 Koolhydraten'},
  {'key': 'Pantry',         'label': '🥫 Pantry'},
  {'key': 'Snacks',         'label': '🍿 Snacks'},
  {'key': 'Drinken',        'label': '🥤 Drinken'},
  {'key': 'Huishouden',     'label': '🧹 Huishouden'},
  {'key': 'Overig',         'label': '📦 Overig'},
];

const List<Map<String, String>> _kMacros = [
  {'key': 'Protein',  'label': '💪 Proteïne'},
  {'key': 'Carbs',    'label': '🍞 Koolhydraten'},
  {'key': 'Fat',      'label': '🧈 Vetten'},
  {'key': 'Balanced', 'label': '⚖️ Gebalanceerd'},
];

// ── Page ───────────────────────────────────────────────────────────────────────

class ProductCatalogPage extends StatefulWidget {
  final String storeName;
  const ProductCatalogPage({super.key, required this.storeName});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  // --- DATA STATE ---
  List<dynamic> _promotions = [];
  List<dynamic> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _showPromoOnly = true;
  int _selectedIndex = 0;
  int _promoDisplayLimit = 25;
  int _searchDisplayLimit = 50;
  final TextEditingController _searchController = TextEditingController();

  // --- FILTER STATE ---
  String? _selectedCategory;
  String? _selectedMacro;
  bool _healthyOnly = false;
  bool _multiItemOnly = false;
  // 'none' | 'price_asc' | 'price_desc' | 'discount_desc' | 'name_asc'
  String _sortOrder = 'none';

  // --- STYLING ---
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);
  final Color backgroundGrey = const Color(0xFFF5F7F9);

  String get _baseUrl {
    if (kIsWeb) return 'http://localhost:8081';
    if (Platform.isAndroid) return 'http://10.0.2.2:8081';
    return 'http://localhost:8081';
  }

  // ── Computed: filtered + sorted list ────────────────────────────────────────

  List<dynamic> get _filteredList {
    final source = _showPromoOnly ? _promotions : _searchResults;
    var list = List<dynamic>.from(source);

    // Category filter (promotions → 'category', search → 'colruyt_category')
    if (_selectedCategory != null) {
      list = list.where((item) {
        final cat = item['category'] ?? item['colruyt_category'];
        return cat == _selectedCategory;
      }).toList();
    }

    // Primary macro (promotions only)
    if (_selectedMacro != null) {
      list = list.where((item) => item['primary_macro'] == _selectedMacro).toList();
    }

    // Healthy only
    if (_healthyOnly) {
      list = list.where((item) => item['is_healthy'] == true).toList();
    }

    // Multi-item deals only (1+1 GRATIS, etc.)
    if (_multiItemOnly) {
      list = list.where((item) => item['is_meerdere_artikels'] == true).toList();
    }

    // Sort
    switch (_sortOrder) {
      case 'price_asc':
        list.sort((a, b) {
          final pa = (a['promo_price'] ?? a['price'] ?? 0).toDouble();
          final pb = (b['promo_price'] ?? b['price'] ?? 0).toDouble();
          return pa.compareTo(pb);
        });
        break;
      case 'price_desc':
        list.sort((a, b) {
          final pa = (a['promo_price'] ?? a['price'] ?? 0).toDouble();
          final pb = (b['promo_price'] ?? b['price'] ?? 0).toDouble();
          return pb.compareTo(pa);
        });
        break;
      case 'discount_desc':
        // Grootste absolute besparing eerst
        list.sort((a, b) {
          final sa = ((a['original_price'] ?? 0) - (a['promo_price'] ?? 0)).toDouble();
          final sb = ((b['original_price'] ?? 0) - (b['promo_price'] ?? 0)).toDouble();
          return sb.compareTo(sa);
        });
        break;
      case 'name_asc':
        list.sort((a, b) =>
            (a['product_name'] ?? '').toString().compareTo((b['product_name'] ?? '').toString()));
        break;
    }

    return list;
  }

  int get _activeFilterCount {
    int n = 0;
    if (_selectedCategory != null) n++;
    if (_selectedMacro != null) n++;
    if (_healthyOnly) n++;
    if (_multiItemOnly) n++;
    if (_sortOrder != 'none') n++;
    return n;
  }

  void _resetFilters() => setState(() {
        _selectedCategory = null;
        _selectedMacro = null;
        _healthyOnly = false;
        _multiItemOnly = false;
        _sortOrder = 'none';
      });

  // ── Data fetching ────────────────────────────────────────────────────────────

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
        queryParameters: {'q': query, 'store_name': widget.storeName},
      );
      setState(() {
        _searchResults = response.data['products'] ?? [];
        _showPromoOnly = false;
        _searchDisplayLimit = 50;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      print("Zoekfout: $e");
    }
  }

  // ── Navbar ───────────────────────────────────────────────────────────────────

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

  // ── Filter bottom sheet ──────────────────────────────────────────────────────

  void _showFilterSheet() {
    // Local temp state so changes only apply on "Toepassen"
    String? tempCategory = _selectedCategory;
    String? tempMacro = _selectedMacro;
    bool tempHealthy = _healthyOnly;
    bool tempMultiItem = _multiItemOnly;
    String tempSort = _sortOrder;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters & sortering',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
                  TextButton(
                    onPressed: () => setModal(() {
                      tempCategory = null;
                      tempMacro = null;
                      tempHealthy = false;
                      tempMultiItem = false;
                      tempSort = 'none';
                    }),
                    child: Text('Wis alles', style: TextStyle(color: brandGreen)),
                  ),
                ],
              ),
              const Divider(height: 24),

              // ── Sorteren ──
              Text('Sorteren',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textDark)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _sortChip('none',          '⭐ Standaard',        tempSort, (v) => setModal(() => tempSort = v)),
                  _sortChip('price_asc',     '💰 Prijs laag→hoog',  tempSort, (v) => setModal(() => tempSort = v)),
                  _sortChip('price_desc',    '💰 Prijs hoog→laag',  tempSort, (v) => setModal(() => tempSort = v)),
                  _sortChip('discount_desc', '🔥 Grootste korting', tempSort, (v) => setModal(() => tempSort = v)),
                  _sortChip('name_asc',      '🔤 Naam A-Z',         tempSort, (v) => setModal(() => tempSort = v)),
                ],
              ),
              const Divider(height: 24),

              // ── Macro ──
              Text('Hoofdmacro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textDark)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _kMacros.map((m) {
                  final sel = tempMacro == m['key'];
                  return ChoiceChip(
                    label: Text(m['label']!),
                    selected: sel,
                    onSelected: (_) => setModal(() => tempMacro = sel ? null : m['key']),
                    selectedColor: brandGreen,
                    labelStyle: TextStyle(color: sel ? Colors.white : textDark, fontSize: 13),
                    backgroundColor: backgroundGrey,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
              const Divider(height: 24),

              // ── Extra filters ──
              Text('Extra filters',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: textDark)),
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('🌿 Alleen gezonde producten'),
                value: tempHealthy,
                onChanged: (v) => setModal(() => tempHealthy = v),
                activeThumbColor: brandGreen,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('🛒 Alleen multi-item deals'),
                subtitle: const Text('1+1 GRATIS, 2+1, 6+6...', style: TextStyle(fontSize: 12)),
                value: tempMultiItem,
                onChanged: (v) => setModal(() => tempMultiItem = v),
                activeThumbColor: brandGreen,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // ── Toepassen ──
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = tempCategory;
                      _selectedMacro = tempMacro;
                      _healthyOnly = tempHealthy;
                      _multiItemOnly = tempMultiItem;
                      _sortOrder = tempSort;
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Toepassen',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String value, String label, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(value),
      selectedColor: brandGreen,
      labelStyle: TextStyle(color: selected ? Colors.white : textDark, fontSize: 13),
      backgroundColor: backgroundGrey,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredList;
    final displayList = _showPromoOnly
        ? filtered.take(_promoDisplayLimit).toList()
        : filtered.take(_searchDisplayLimit).toList();

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

          // ── Zoekbalk + filter knop ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchProducts,
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
                      fillColor: backgroundGrey,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter knop met badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: _activeFilterCount > 0 ? brandGreen : backgroundGrey,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showFilterSheet,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.tune_rounded,
                              color: _activeFilterCount > 0 ? Colors.white : Colors.grey[600]),
                        ),
                      ),
                    ),
                    if (_activeFilterCount > 0)
                      Positioned(
                        top: -4, right: -4,
                        child: Container(
                          width: 18, height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: Text('$_activeFilterCount',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Category chips ──────────────────────────────────────────────────
          Container(
            color: Colors.white,
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _kCategories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _kCategories[i];
                final selected = _selectedCategory == cat['key'];
                return GestureDetector(
                  onTap: () => setState(() =>
                      _selectedCategory = selected ? null : cat['key']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? brandGreen : backgroundGrey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat['label']!,
                      style: TextStyle(
                        color: selected ? Colors.white : textDark,
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Header: count + filters wissen ─────────────────────────────────
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    Icon(_showPromoOnly ? Icons.local_offer : Icons.search,
                        size: 16, color: brandGreen),
                    const SizedBox(width: 6),
                    Text(
                      _showPromoOnly
                          ? "${filtered.length} promoties"
                          : "${filtered.length} resultaten",
                      style: TextStyle(
                          color: textDark, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ]),
                  if (_activeFilterCount > 0)
                    GestureDetector(
                      onTap: _resetFilters,
                      child: Row(children: [
                        Icon(Icons.close, size: 14, color: Colors.grey[500]),
                        const SizedBox(width: 2),
                        Text('Filters wissen',
                            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                      ]),
                    ),
                ],
              ),
            ),

          // ── Grid ───────────────────────────────────────────────────────────
          Expanded(
            child: _isLoading || _isSearching
                ? Center(child: CircularProgressIndicator(color: brandGreen))
                : filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text(
                              _activeFilterCount > 0
                                  ? "Geen resultaten voor deze filters"
                                  : _showPromoOnly
                                      ? "Geen promoties voor ${widget.storeName}"
                                      : "Geen producten gevonden",
                              style: TextStyle(color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                            if (_activeFilterCount > 0) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _resetFilters,
                                child: Text('Filters wissen',
                                    style: TextStyle(color: brandGreen)),
                              ),
                            ],
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
                          if (_showPromoOnly && _promoDisplayLimit < filtered.length)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _promoDisplayLimit += 25),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: brandGreen,
                                    side: BorderSide(color: brandGreen),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    "Meer laden (${filtered.length - _promoDisplayLimit} resterend)",
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ),
                          if (!_showPromoOnly && _searchDisplayLimit < filtered.length)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => _searchDisplayLimit += 50),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: brandGreen,
                                    side: BorderSide(color: brandGreen),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                  ),
                                  child: Text(
                                    "Meer laden (${filtered.length - _searchDisplayLimit} resterend)",
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

  // ── Promotie kaart ───────────────────────────────────────────────────────────

  Widget _buildPromoCard(Map<String, dynamic> promo) {
    final String name = promo['product_name'] ?? 'Onbekend';
    final String? discount = promo['discount_percentage'];
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
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                child: SizedBox(
                  height: 110,
                  width: double.infinity,
                  child: imageUrl != null
                      ? Image.network(imageUrl, fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)))
                      : const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
                ),
              ),
              if (discount != null && discount.isNotEmpty)
                Positioned(
                  top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red, borderRadius: BorderRadius.circular(6)),
                    child: Text(discount,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              if (isHealthy)
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: brandGreen, shape: BoxShape.circle),
                    child: const Icon(Icons.eco, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (promoPrice != null)
                      Text("€${promoPrice.toStringAsFixed(2)}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15, color: brandGreen)),
                    const SizedBox(width: 6),
                    if (originalPrice != null)
                      Text("€${originalPrice.toStringAsFixed(2)}",
                          style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              decoration: TextDecoration.lineThrough)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Product kaart (zoekresultaten) ───────────────────────────────────────────

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['product_name'] ?? 'Onbekend';
    final String? rawImageUrl = product['image_url'];
    final String? imageUrl = rawImageUrl != null
        ? '$_baseUrl/proxy/image?url=${Uri.encodeQueryComponent(rawImageUrl)}'
        : null;
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
                      errorBuilder: (_, _, _) =>
                          const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)))
                  : const Center(child: Icon(Icons.image, size: 40, color: Colors.grey)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                if (content != null) ...[
                  const SizedBox(height: 2),
                  Text(content, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
                const SizedBox(height: 6),
                if (price != null)
                  Text("€${price.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

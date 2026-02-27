import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ShoppingList/shopping_list_page.dart';
import 'ShoppingList/shopping_list_detail_page.dart';
import 'screens/barcode_scanner_screen.dart';
import 'services/shopping_list_service.dart';
import 'services/suggestion_service.dart';

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

  // --- CART SESSION STATE ---
  int _addedCount = 0;
  String? _lastListId;
  String? _lastListName;

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
                activeColor: brandGreen,
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('🛒 Alleen multi-item deals'),
                subtitle: const Text('1+1 GRATIS, 2+1, 6+6...', style: TextStyle(fontSize: 12)),
                value: tempMultiItem,
                onChanged: (v) => setModal(() => tempMultiItem = v),
                activeColor: brandGreen,
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

  // ── Add to shopping list ─────────────────────────────────────────────────────

  void _showAddToListSheet(Map<String, dynamic> product) {
    final String productId = product['product_id']?.toString() ?? '';
    if (productId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dit product kan niet worden toegevoegd')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddToListSheet(
        product: product,
        baseUrl: _baseUrl,
        brandGreen: brandGreen,
        storeName: widget.storeName,
        onAdded: (String listId, String listName) {
          setState(() {
            _addedCount++;
            _lastListId = listId;
            _lastListName = listName;
          });
          _showSuggestionsPrompt(listId, listName);
        },
      ),
    );
  }

  void _showSuggestionsPrompt(String listId, String listName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Product toegevoegd!'),
        action: SnackBarAction(
          label: 'AI Suggesties',
          textColor: Colors.white,
          onPressed: () => _triggerAiSuggestions(listId),
        ),
        backgroundColor: brandGreen,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _triggerAiSuggestions(String listId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    // Toon loading sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SuggestionsLoadingSheet(),
    );

    try {
      // Haal items op uit de lijst
      final items = await ShoppingListService.getListItems(listId);
      final productNames = items
          .map((item) => item['product_name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();

      if (productNames.isEmpty) {
        if (!mounted) return;
        Navigator.pop(context);
        return;
      }

      final result = await SuggestionService.getPromotionSuggestions(
        storeName: widget.storeName,
        scannedProducts: productNames,
      );

      if (!mounted) return;
      Navigator.pop(context); // sluit loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _CatalogSuggestionsSheet(
          data: result,
          brandGreen: brandGreen,
          onAddSuggestion: (String productName) {
            // Zoek het product in de promoties lijst en voeg toe als gevonden
            final match = _promotions.firstWhere(
              (p) => (p['product_name'] ?? '').toString().toLowerCase() ==
                  productName.toLowerCase(),
              orElse: () => <String, dynamic>{},
            );
            if (match.isNotEmpty && match['product_id'] != null && _lastListId != null) {
              _addSuggestionToList(match, _lastListId!, _lastListName ?? 'Lijst');
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij suggesties: $e')),
      );
    }
  }

  Future<void> _addSuggestionToList(
      Map<String, dynamic> product, String listId, String listName) async {
    try {
      await ShoppingListService.addItemByProductId(
        listId: listId,
        productId: product['product_id'].toString(),
      );
      if (!mounted) return;
      setState(() => _addedCount++);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product['product_name']} toegevoegd aan $listName'),
          backgroundColor: brandGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
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
      floatingActionButton: _addedCount > 0 && _lastListId != null
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShoppingListDetailPage(
                      listId: _lastListId!,
                      listName: _lastListName ?? 'Lijst',
                    ),
                  ),
                );
              },
              backgroundColor: brandGreen,
              icon: const Icon(Icons.shopping_cart, color: Colors.white),
              label: Text(
                '$_addedCount ${_addedCount == 1 ? 'item' : 'items'}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
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
              separatorBuilder: (_, __) => const SizedBox(width: 8),
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

    return GestureDetector(
      onTap: () => _showAddToListSheet(promo),
      child: Card(
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
                            errorBuilder: (_, __, ___) =>
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

    return GestureDetector(
      onTap: () => _showAddToListSheet(product),
      child: Card(
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
                        errorBuilder: (_, __, ___) =>
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Add to List Bottom Sheet
// ══════════════════════════════════════════════════════════════════════════════

class _AddToListSheet extends StatefulWidget {
  final Map<String, dynamic> product;
  final String baseUrl;
  final Color brandGreen;
  final String storeName;
  final void Function(String listId, String listName) onAdded;

  const _AddToListSheet({
    required this.product,
    required this.baseUrl,
    required this.brandGreen,
    required this.storeName,
    required this.onAdded,
  });

  @override
  State<_AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<_AddToListSheet> {
  List<Map<String, dynamic>> _lists = [];
  bool _isLoadingLists = true;
  bool _isAdding = false;
  bool _showNewListField = false;
  final TextEditingController _newListController = TextEditingController();

  // Promo quantity
  late int _quantity;
  late bool _hasPromo;
  late int _dealQuantity;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _hasPromo = p['promo_price'] != null;
    _dealQuantity = (p['deal_quantity'] as int?) ?? 1;
    final isMulti = p['is_meerdere_artikels'] == true;
    // Stel deal-hoeveelheid voor als het een multi-item deal is
    _quantity = (isMulti && _dealQuantity > 1) ? _dealQuantity : 1;
    _fetchLists();
  }

  @override
  void dispose() {
    _newListController.dispose();
    super.dispose();
  }

  Future<void> _fetchLists() async {
    try {
      final lists = await ShoppingListService.getUserLists();
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _isLoadingLists = false;
        // Als er geen lijsten zijn, toon meteen het "nieuwe lijst" veld
        if (lists.isEmpty) _showNewListField = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingLists = false;
        _showNewListField = true;
      });
    }
  }

  Future<void> _addToList(String listId, String listName) async {
    setState(() => _isAdding = true);
    try {
      final p = widget.product;
      final promoPrice = p['promo_price'] != null
          ? double.tryParse(p['promo_price'].toString())
          : null;
      final originalPrice = p['original_price'] != null
          ? double.tryParse(p['original_price'].toString())
          : (p['price'] != null ? double.tryParse(p['price'].toString()) : null);

      await ShoppingListService.addItemByProductId(
        listId: listId,
        productId: p['product_id'].toString(),
        quantity: _quantity,
        hasPromo: _hasPromo,
        promoId: _hasPromo ? p['promo_id']?.toString() : null,
        pricePerUnit: promoPrice ?? originalPrice,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onAdded(listId, listName);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij toevoegen: $e')),
      );
    }
  }

  Future<void> _createNewListAndAdd() async {
    final name = _newListController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      final newList = await ShoppingListService.createListAndReturn(listName: name);
      final listId = newList['list_id'] as String;
      await _addToList(listId, name);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAdding = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  // ── Helpers ──

  String? _formatNum(dynamic val) {
    if (val == null) return null;
    final d = double.tryParse(val.toString());
    if (d == null) return null;
    return d.toStringAsFixed(1);
  }

  String _formatDate(dynamic val) {
    if (val == null) return '?';
    try {
      final dt = DateTime.parse(val.toString());
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return val.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final productName = p['product_name'] ?? 'Onbekend';
    final promoPrice = p['promo_price'];
    final originalPrice = p['original_price'];
    final price = p['price'];
    final discountLabel = p['discount_label'] ?? p['discount_percentage'];
    final validFrom = p['valid_from'];
    final validUntil = p['valid_until'];
    final category = p['category'] ?? p['colruyt_category'];
    final primaryMacro = p['primary_macro'];
    final bool isHealthy = p['is_healthy'] ?? false;
    final brand = p['brand'];

    // Macros
    final kcal = _formatNum(p['energy_kcal']);
    final protein = _formatNum(p['proteins_g']);
    final carbs = _formatNum(p['carbohydrates_g']);
    final fat = _formatNum(p['fat_g']);
    final bool hasMacros = kcal != null || protein != null;

    final String? rawImageUrl = p['image_url'];
    final String? imageUrl = rawImageUrl != null
        ? '${widget.baseUrl}/proxy/image?url=${Uri.encodeQueryComponent(rawImageUrl)}'
        : null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Handle ──
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ═══════════════════════════════════════════════════════
            // PRODUCT DETAIL SECTION
            // ═══════════════════════════════════════════════════════

            // Afbeelding + naam + prijs
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 80, height: 80,
                    color: Colors.grey[100],
                    child: imageUrl != null
                        ? Image.network(imageUrl, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                const Center(child: Icon(Icons.image, size: 36, color: Colors.grey)))
                        : const Center(child: Icon(Icons.image, size: 36, color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(productName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (brand != null)
                        Text(brand.toString(),
                            style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(height: 6),
                      // Prijs rij
                      Row(
                        children: [
                          if (promoPrice != null)
                            Text(
                              "€${double.tryParse(promoPrice.toString())?.toStringAsFixed(2) ?? promoPrice}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18,
                                color: widget.brandGreen,
                              ),
                            ),
                          if (promoPrice != null && originalPrice != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                "€${double.tryParse(originalPrice.toString())?.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  color: Colors.grey, fontSize: 13,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          if (promoPrice == null && price != null)
                            Text(
                              "€${double.tryParse(price.toString())?.toStringAsFixed(2) ?? price}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Promotie info chips ──
            Wrap(
              spacing: 8, runSpacing: 6,
              children: [
                if (discountLabel != null && discountLabel.toString().isNotEmpty)
                  _infoChip(discountLabel.toString(), Colors.red, Colors.white, icon: Icons.local_offer),
                if (isHealthy)
                  _infoChip('Gezond', Colors.green.shade50, Colors.green.shade700, icon: Icons.eco),
                if (category != null)
                  _infoChip(category.toString(), Colors.blue.shade50, Colors.blue.shade700, icon: Icons.category),
                if (primaryMacro != null && primaryMacro != 'None')
                  _infoChip(primaryMacro.toString(), Colors.orange.shade50, Colors.orange.shade700, icon: Icons.fitness_center),
                if (validFrom != null && validUntil != null)
                  _infoChip(
                    '${_formatDate(validFrom)} - ${_formatDate(validUntil)}',
                    Colors.purple.shade50, Colors.purple.shade700,
                    icon: Icons.calendar_today,
                  ),
              ],
            ),

            // ── Macros balk ──
            if (hasMacros) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    if (kcal != null) _macroColumn('Kcal', kcal, Colors.orange),
                    if (protein != null) _macroColumn('Eiwit', '${protein}g', Colors.red),
                    if (carbs != null) _macroColumn('Koolh', '${carbs}g', Colors.blue),
                    if (fat != null) _macroColumn('Vet', '${fat}g', Colors.amber),
                  ],
                ),
              ),
            ],

            // ═══════════════════════════════════════════════════════
            // PROMO DEAL SUGGESTIE
            // ═══════════════════════════════════════════════════════

            if (_hasPromo && _dealQuantity > 1) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_offer, size: 16, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            discountLabel != null
                                ? 'Promotie: $discountLabel — koop er $_dealQuantity!'
                                : 'Multi-deal: koop er $_dealQuantity voor maximale besparing!',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (promoPrice != null && originalPrice != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        () {
                          final op = double.tryParse(originalPrice.toString()) ?? 0;
                          final pp = double.tryParse(promoPrice.toString()) ?? 0;
                          final totalNormal = op * _dealQuantity;
                          final totalPromo = pp * _dealQuantity;
                          final saving = totalNormal - totalPromo;
                          return 'Normaal: €${totalNormal.toStringAsFixed(2)} → Nu: €${totalPromo.toStringAsFixed(2)} (bespaar €${saving.toStringAsFixed(2)})';
                        }(),
                        style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ═══════════════════════════════════════════════════════
            // HOEVEELHEID SELECTOR
            // ═══════════════════════════════════════════════════════

            Row(
              children: [
                const Text('Aantal:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 18),
                        onPressed: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                      Container(
                        width: 36,
                        alignment: Alignment.center,
                        child: Text(
                          '$_quantity',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add, size: 18),
                        onPressed: () => setState(() => _quantity++),
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Prijs overzicht
            if (promoPrice != null || price != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  () {
                    final unitPrice = double.tryParse((promoPrice ?? price).toString()) ?? 0;
                    return '$_quantity × €${unitPrice.toStringAsFixed(2)} = €${(unitPrice * _quantity).toStringAsFixed(2)}';
                  }(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],

            // ═══════════════════════════════════════════════════════
            // TOEVOEGEN AAN LIJST SECTION
            // ═══════════════════════════════════════════════════════

            const Divider(height: 24),

            const Text(
              'Toevoegen aan lijst',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            // Loading of lijsten
            if (_isLoadingLists)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else ...[
              // Bestaande lijsten
              if (_lists.isNotEmpty) ...[
                ...(_lists.map((list) {
                  final listName = list['list_name'] ?? '';
                  final listId = list['list_id'] ?? '';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.list_alt, color: widget.brandGreen, size: 22),
                    title: Text(listName, style: const TextStyle(fontSize: 14)),
                    trailing: _isAdding
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.add_circle_outline, color: widget.brandGreen),
                    onTap: _isAdding ? null : () => _addToList(listId, listName),
                  );
                })),
                const Divider(height: 4),
              ],

              // Nieuwe lijst aanmaken
              if (!_showNewListField)
                TextButton.icon(
                  onPressed: () => setState(() => _showNewListField = true),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Nieuwe lijst aanmaken'),
                  style: TextButton.styleFrom(
                    foregroundColor: widget.brandGreen,
                    padding: EdgeInsets.zero,
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newListController,
                        autofocus: _lists.isEmpty,
                        decoration: InputDecoration(
                          hintText: 'Naam van nieuwe lijst',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        ),
                        onSubmitted: (_) => _createNewListAndAdd(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isAdding ? null : _createNewListAndAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.brandGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      ),
                      child: _isAdding
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Aanmaken & toevoegen'),
                    ),
                  ],
                ),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String label, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _macroColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Suggestions Sheets (voor catalog page)
// ══════════════════════════════════════════════════════════════════════════════

class _SuggestionsLoadingSheet extends StatelessWidget {
  const _SuggestionsLoadingSheet();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI suggesties laden...'),
          ],
        ),
      ),
    );
  }
}

class _CatalogSuggestionsSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color brandGreen;
  final void Function(String productName)? onAddSuggestion;

  const _CatalogSuggestionsSheet({
    required this.data,
    required this.brandGreen,
    this.onAddSuggestion,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = data['suggestions'] as List<dynamic>? ?? [];
    final mealTip = data['meal_tip'] as String? ?? '';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Suggesties voor jou',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (mealTip.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mealTip,
                        style: TextStyle(color: Colors.green.shade800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, index) {
                  final s = suggestions[index] as Map<String, dynamic>;
                  final isPromotion = s['is_promotion'] ?? (s['discount_label'] != null);
                  final productName = s['product_name'] ?? '';

                  return ListTile(
                    leading: Icon(
                      s['is_healthy'] == true ? Icons.eco : Icons.shopping_bag_outlined,
                      color: s['is_healthy'] == true ? Colors.green : Colors.grey,
                    ),
                    title: Text(productName),
                    subtitle: Text(
                      s['reason'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isPromotion && s['discount_label'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  s['discount_label'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Text(
                                'Geen promotie',
                                style: TextStyle(color: Colors.grey[500], fontSize: 10),
                              ),
                            if (s['promo_price'] != null)
                              Text(
                                '€${(s['promo_price'] as num).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: brandGreen,
                                ),
                              ),
                          ],
                        ),
                        if (onAddSuggestion != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.add_circle, color: brandGreen),
                            onPressed: () => onAddSuggestion!(productName),
                            tooltip: 'Toevoegen aan lijst',
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

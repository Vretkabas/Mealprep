import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';
import '../services/suggestion_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingListDetailPage extends StatefulWidget {
  final String listId;
  final String listName;

  const ShoppingListDetailPage({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<ShoppingListDetailPage> createState() => _ShoppingListDetailPageState();
}

class _ShoppingListDetailPageState extends State<ShoppingListDetailPage> {
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _barcodeController = TextEditingController();
  bool _isLoading = true;
  final Set<String> _selectedItemIds = {};

  // Styling
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);
  final Color bgGrey = const Color(0xFFF5F7F9);

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // ── Data ─────────────────────────────────────────────────────────────────────

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ShoppingListService.getListItems(widget.listId);
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout bij laden items: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addItemByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;
    try {
      await ShoppingListService.addItemByBarcode(
        listId: widget.listId,
        barcode: barcode,
      );
      _barcodeController.clear();
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kon item niet toevoegen: $e')));
    }
  }

  // ── Berekeningen ──────────────────────────────────────────────────────────────

  double get _totalPrice {
    double total = 0;
    for (final item in _items) {
      final lineTotal = item['line_total'];
      if (lineTotal != null) {
        total += (lineTotal is num) ? lineTotal.toDouble() : (double.tryParse(lineTotal.toString()) ?? 0);
      }
    }
    return total;
  }

  double get _totalSavings {
    double savings = 0;
    for (final item in _items) {
      final savingsPerUnit = item['savings_per_unit'];
      final quantity = item['quantity'] ?? 1;
      if (savingsPerUnit != null && (item['has_promo'] == true)) {
        savings += ((savingsPerUnit is num) ? savingsPerUnit.toDouble() : 0) * quantity;
      }
    }
    return savings;
  }

  int get _checkedCount => _items.where((i) => i['is_checked'] == true).length;

  // ── Selectie acties ───────────────────────────────────────────────────────────

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  Future<void> _toggleCheckedSelected() async {
    final allChecked = _selectedItemIds.every((id) {
      final item = _items.firstWhere((i) => i['item_id'] == id);
      return item['is_checked'] == true;
    });
    try {
      for (final itemId in _selectedItemIds) {
        await ShoppingListService.updateItemChecked(
          itemId: itemId,
          isChecked: !allChecked,
        );
      }
      setState(() => _selectedItemIds.clear());
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  Future<void> _deleteSelected() async {
    try {
      for (final itemId in _selectedItemIds) {
        await ShoppingListService.deleteItem(itemId: itemId);
      }
      setState(() => _selectedItemIds.clear());
      await _loadItems();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $e')));
    }
  }

  Future<void> _editQuantity(String itemId, int currentQuantity) async {
    final controller = TextEditingController(text: currentQuantity.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aantal aanpassen'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Nieuw aantal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('Opslaan'),
          ),
        ],
      ),
    );
    if (result != null) {
      try {
        await ShoppingListService.updateItemQuantity(itemId: itemId, quantity: result);
        await _loadItems();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Fout: $e')));
      }
    }
  }

  // ── AI Suggesties ─────────────────────────────────────────────────────────────

  Future<void> _showAiSuggestions(BuildContext context) async {
    final productNames = _items
        .map((item) => item['product_name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();

    if (productNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voeg eerst producten toe aan je lijst.')),
      );
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Niet ingelogd.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const _SuggestionsLoadingSheet(),
    );

    try {
      final result = await SuggestionService.getPromotionSuggestions(
        storeName: 'Colruyt',
        scannedProducts: productNames,
      );

      if (!context.mounted) return;
      Navigator.pop(context);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _SuggestionsSheet(data: result),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout: $e')),
      );
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedItemIds.isNotEmpty;
    final uncheckedItems = _items.where((i) => i['is_checked'] != true).toList();
    final checkedItems = _items.where((i) => i['is_checked'] == true).toList();

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Text(widget.listName, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: hasSelection
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: brandGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_selectedItemIds.length} geselecteerd',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: brandGreen,
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandGreen))
          : Column(
              children: [
                // ── Samenvatting balk ──
                _buildSummaryBar(),

                // ── Lijst items ──
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shopping_cart_outlined,
                                  size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Je lijst is nog leeg',
                                style: TextStyle(color: Colors.grey[500], fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Voeg producten toe vanuit de catalogus',
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadItems,
                          color: brandGreen,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            children: [
                              // Nog te kopen
                              if (uncheckedItems.isNotEmpty) ...[
                                _sectionHeader(
                                  'Nog te kopen',
                                  '${uncheckedItems.length} ${uncheckedItems.length == 1 ? 'item' : 'items'}',
                                  Icons.shopping_bag_outlined,
                                ),
                                const SizedBox(height: 8),
                                ...uncheckedItems.map(_buildItemCard),
                              ],

                              // Aangekocht
                              if (checkedItems.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _sectionHeader(
                                  'Aangekocht',
                                  '${checkedItems.length} ${checkedItems.length == 1 ? 'item' : 'items'}',
                                  Icons.check_circle_outline,
                                ),
                                const SizedBox(height: 8),
                                ...checkedItems.map(_buildItemCard),
                              ],
                            ],
                          ),
                        ),
                ),

                // ── Selectie actie balk ──
                if (hasSelection) _buildSelectionBar(),

                // ── Onderste acties ──
                _buildBottomBar(),
              ],
            ),
    );
  }

  // ── Samenvatting bovenaan ───────────────────────────────────────────────────

  Widget _buildSummaryBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Totaal
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Geschatte totaal',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                const SizedBox(height: 2),
                Text(
                  '€${_totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),

          // Besparing
          if (_totalSavings > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.savings_outlined, size: 18, color: Colors.green.shade700),
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bespaard',
                          style: TextStyle(color: Colors.green.shade600, fontSize: 10)),
                      Text(
                        '€${_totalSavings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(width: 12),

          // Voortgang
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Voortgang',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              const SizedBox(height: 2),
              Text(
                '$_checkedCount / ${_items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _checkedCount == _items.length && _items.isNotEmpty
                      ? brandGreen
                      : textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Sectie header ──────────────────────────────────────────────────────────

  Widget _sectionHeader(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: brandGreen),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: textDark)),
        const Spacer(),
        Text(subtitle,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
  }

  // ── Item kaart ─────────────────────────────────────────────────────────────

  Widget _buildItemCard(Map<String, dynamic> item) {
    final itemId = item['item_id'] as String;
    final isSelected = _selectedItemIds.contains(itemId);
    final isChecked = item['is_checked'] ?? false;
    final productName = item['product_name'] ?? 'Onbekend';
    final brand = item['brand'];
    final quantity = item['quantity'] ?? 1;
    final hasPromo = item['has_promo'] == true;
    final pricePerUnit = item['price_per_unit'] != null
        ? (item['price_per_unit'] is num
            ? (item['price_per_unit'] as num).toDouble()
            : double.tryParse(item['price_per_unit'].toString()))
        : null;
    final originalPrice = item['original_price'] != null
        ? (item['original_price'] is num
            ? (item['original_price'] as num).toDouble()
            : double.tryParse(item['original_price'].toString()))
        : null;
    final lineTotal = item['line_total'] != null
        ? (item['line_total'] is num
            ? (item['line_total'] as num).toDouble()
            : double.tryParse(item['line_total'].toString()))
        : null;
    final discountLabel = item['discount_label'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          if (item['barcode'] != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductScreen(barcode: item['barcode']),
              ),
            );
          }
        },
        onLongPress: () => _toggleSelection(itemId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isChecked ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? Border.all(color: brandGreen, width: 2)
                : Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: isChecked
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Checkbox / selectie
                GestureDetector(
                  onTap: () => _toggleSelection(itemId),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? brandGreen
                          : isChecked
                              ? Colors.green.shade100
                              : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? brandGreen
                            : isChecked
                                ? Colors.green
                                : Colors.grey.shade400,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isSelected || isChecked
                        ? Icon(Icons.check,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.green)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),

                // Product info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isChecked ? Colors.grey : textDark,
                          decoration:
                              isChecked ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (brand != null)
                            Text('$brand · ',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 11)),
                          GestureDetector(
                            onTap: () => _editQuantity(itemId, quantity),
                            child: Text(
                              '$quantity ${quantity == 1 ? 'stuk' : 'stuks'}',
                              style: TextStyle(
                                color: brandGreen,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                decoration: TextDecoration.underline,
                                decorationColor: brandGreen,
                              ),
                            ),
                          ),
                          if (hasPromo && discountLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                discountLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Prijs rechts
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (lineTotal != null)
                      Text(
                        '€${lineTotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isChecked ? Colors.grey : textDark,
                        ),
                      ),
                    if (pricePerUnit != null && quantity > 1)
                      Text(
                        '€${pricePerUnit.toStringAsFixed(2)}/st',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    if (hasPromo && originalPrice != null && pricePerUnit != null && originalPrice > pricePerUnit)
                      Text(
                        '€${originalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 10,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Selectie actie balk ────────────────────────────────────────────────────

  Widget _buildSelectionBar() {
    final allChecked = _selectedItemIds.every((id) {
      final item = _items.firstWhere((i) => i['item_id'] == id);
      return item['is_checked'] == true;
    });

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _toggleCheckedSelected,
            icon: Icon(
              allChecked ? Icons.remove_circle_outline : Icons.check_circle_outline,
              color: allChecked ? Colors.orange : Colors.green,
            ),
            label: Text(
              allChecked ? 'Niet aangekocht' : 'Aangekocht',
              style: TextStyle(
                color: allChecked ? Colors.orange : Colors.green,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Onderste balk ──────────────────────────────────────────────────────────

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AI Suggesties knop
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showAiSuggestions(context),
              icon: Icon(Icons.auto_awesome, size: 18, color: brandGreen),
              label: Text('AI Suggesties',
                  style: TextStyle(color: brandGreen, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: brandGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Barcode toevoegen
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    hintText: 'Barcode invoeren...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    prefixIcon:
                        Icon(Icons.qr_code_scanner, color: Colors.grey[400], size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addItemByBarcode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Toevoegen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Suggestions Sheets
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

class _SuggestionsSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SuggestionsSheet({required this.data});

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
            Center(
              child: Container(
                width: 40,
                height: 4,
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
                    Icon(Icons.lightbulb_outline,
                        size: 18, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mealTip,
                        style: TextStyle(
                            color: Colors.green.shade800, fontSize: 13),
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
                  return ListTile(
                    leading: s['is_healthy'] == true
                        ? const Icon(Icons.eco, color: Colors.green)
                        : const Icon(Icons.shopping_bag_outlined),
                    title: Text(s['product_name'] ?? ''),
                    subtitle: Text(s['reason'] ?? '',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (s['discount_label'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
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
                          ),
                        if (s['promo_price'] != null)
                          Text(
                            '€${(s['promo_price'] as num).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
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

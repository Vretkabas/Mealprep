import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  // 🔹 Items van deze lijst ophalen
  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await ShoppingListService.getListItems(widget.listId);
      setState(() => _items = items);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout bij laden items: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 🔹 Product toevoegen via barcode
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Kon item niet toevoegen: $e')));
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.listName)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item['product_name'] ?? 'Onbekend'),
                          subtitle: Text('Aantal: ${item['quantity']}'),
                          trailing: Checkbox(
                            value: item['is_checked'] ?? false,
                            onChanged: (val) {
                              // TODO: later checked status updaten via API
                            },
                          ),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Barcode toevoegen',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItemByBarcode,
                  child: const Text('Toevoegen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

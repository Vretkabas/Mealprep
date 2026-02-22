import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';
import 'package:mealprep_flutter/screens/product_screen.dart';

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
  Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

Future<void> _editQuantity(String itemId, int currentQuantity) async {
  final controller =
      TextEditingController(text: currentQuantity.toString());

  final result = await showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Aantal aanpassen'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nieuw aantal',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Opslaan'),
          ),
        ],
      );
    },
  );

  if (result != null) {
    try {
      await ShoppingListService.updateItemQuantity(
        itemId: itemId,
        quantity: result,
      );
      await _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij aanpassen: $e')),
      );
    }
  }
}

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

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
    });
  }

  Future<void> _markSelectedAsChecked() async {
    try {
      for (final itemId in _selectedItemIds) {
        await ShoppingListService.updateItemChecked(
          itemId: itemId,
          isChecked: true,
        );
      }
      setState(() => _selectedItemIds.clear());
      await _loadItems();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout bij markeren: $e')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Fout bij verwijderen: $e')));
    }
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedItemIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        actions: hasSelection
            ? [
                Text(
                  '${_selectedItemIds.length} geselecteerd',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
              ]
            : null,
      ),
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
                        final itemId = item['item_id'] as String;
                        final isSelected = _selectedItemIds.contains(itemId);
                        final isChecked = item['is_checked'] ?? false;

                        return GestureDetector(
                          onTap: () {
                            if (item['barcode'] != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductScreen(barcode: item['barcode']),
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? Colors.green.shade100
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: isSelected
                                  ? Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    )
                                  : null,
                            ),
                            child: ListTile(
                              title: Text(
                                item['product_name'] ?? 'Onbekend',
                                style: TextStyle(
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: GestureDetector(
                              onTap: () => _editQuantity(itemId, item['quantity']),
                              child: Text(
                                'Aantal: ${item['quantity']}',
                                style: const TextStyle(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                              // Vierkante selectieknop
                              trailing: GestureDetector(
                                onTap: () => _toggleSelection(itemId),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 18, color: Colors.white)
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

            // Actie-balk onderaan bij selectie
            if (hasSelection)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Check of alle geselecteerde items al aangekocht zijn
                  Builder(builder: (context) {
                    final allChecked = _selectedItemIds.every((id) {
                      final item = _items.firstWhere((i) => i['item_id'] == id);
                      return item['is_checked'] == true;
                    });

                    return TextButton.icon(
                      onPressed: () async {
                        try {
                          for (final itemId in _selectedItemIds) {
                            await ShoppingListService.updateItemChecked(
                              itemId: itemId,
                              isChecked: !allChecked, // toggle
                            );
                          }
                          setState(() => _selectedItemIds.clear());
                          await _loadItems();
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Fout: $e')),
                          );
                        }
                      },
                      icon: Icon(
                        allChecked ? Icons.remove_circle_outline : Icons.check_circle_outline,
                        color: allChecked ? Colors.orange : Colors.green,
                      ),
                      label: Text(
                        allChecked ? 'Aankoop annuleren' : 'Aangekocht',
                        style: TextStyle(
                          color: allChecked ? Colors.orange : Colors.green,
                        ),
                      ),
                    );
                  }),

                  TextButton.icon(
                    onPressed: _deleteSelected,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text('Verwijderen', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),

            Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: OutlinedButton.icon(
              onPressed: () {
                // jouw AI suggesties logica
                //_showAiSuggestions(context);
              },
              icon: const Icon(Icons.auto_awesome, size: 18), // sterretje icoon
              label: const Text('Suggesties'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcodeController,
                    decoration: const InputDecoration(
                      labelText: 'Artikel toevoegen',
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

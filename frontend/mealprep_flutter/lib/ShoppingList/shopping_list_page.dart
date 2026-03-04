import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';
import 'package:mealprep_flutter/ShoppingList/create_shopping_list_page.dart';
import 'shopping_list_detail_page.dart';
import 'package:mealprep_flutter/navbar.dart'; 

class ShoppingListsPage extends StatefulWidget {
  const ShoppingListsPage({super.key});

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  List<Map<String, dynamic>> shoppingLists = [];
  bool _isLoading = true;

  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);
  final Color bgGrey = const Color(0xFFF5F7F9);

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    setState(() => _isLoading = true);
    try {
      final lists = await ShoppingListService.getUserLists();
      setState(() {
        shoppingLists = lists;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij ophalen lijsten: $e')),
      );
    }
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const Create_shopping_list_page()),
    );
    if (result == true) _fetchLists();
  }

  Future<void> _deleteList(String listId, String listName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lijst verwijderen'),
        content: Text('Weet je zeker dat je "$listName" wilt verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuleren', style: TextStyle(color: textDark)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ShoppingListService.deleteList(listId: listId);
        _fetchLists();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fout bij verwijderen: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: Text(
          'Mijn lijsten',
          style: TextStyle(fontWeight: FontWeight.bold, color: textDark),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePage,
        backgroundColor: brandGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nieuwe lijst', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: brandGreen))
          : RefreshIndicator(
              onRefresh: _fetchLists,
              color: brandGreen,
              child: shoppingLists.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: shoppingLists.length,
                      itemBuilder: (context, index) =>
                          _buildListCard(shoppingLists[index]),
                    ),
            ),
            bottomNavigationBar: AppBottomNavBar(currentIndex: 2),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: brandGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_cart_outlined, size: 48, color: brandGreen),
            ),
            const SizedBox(height: 20),
            Text(
              'Nog geen lijsten',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Maak een nieuwe lijst via de knop onderaan',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildListCard(Map<String, dynamic> list) {
    final listId = list['list_id'] as String;
    final listName = list['list_name'] ?? 'Onbekende lijst';
    final totalPrice = list['estimated_total_price'];
    final totalSavings = list['estimated_savings'];

    final hasTotals = totalPrice != null && (totalPrice as num) > 0;
    final hasSavings = totalSavings != null && (totalSavings as num) > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ShoppingListDetailPage(
                  listId: listId,
                  listName: listName,
                ),
              ),
            );
            _fetchLists();
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                  child: Row(
                    children: [
                      // Icoon
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: brandGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(Icons.shopping_bag_outlined,
                            color: brandGreen, size: 26),
                      ),
                      const SizedBox(width: 14),

                      // Naam + prijsinfo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              listName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (hasTotals)
                              Row(
                                children: [
                                  Text(
                                    '€${(totalPrice).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: textDark,
                                    ),
                                  ),
                                  if (hasSavings) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: Colors.green.shade200,
                                            width: 0.5),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.savings_outlined,
                                              size: 11,
                                              color: Colors.green.shade700),
                                          const SizedBox(width: 3),
                                          Text(
                                            '-€${(totalSavings).toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.green.shade700,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            else
                              Text(
                                'Nog geen items',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[400]),
                              ),
                          ],
                        ),
                      ),

                      // Verwijder + pijl
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        onPressed: () => _deleteList(listId, listName),
                        splashRadius: 20,
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey[300]),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';
import 'package:mealprep_flutter/ShoppingList/create_shopping_list_page.dart';
import 'shopping_list_detail_page.dart';

class ShoppingListsPage extends StatefulWidget {
  const ShoppingListsPage({super.key});

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  List<Map<String, dynamic>> shoppingLists = [];
  bool _isLoading = true;

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Fout bij ophalen lijsten: $e")),
      );
    }
  }

  Future<void> _openCreatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const Create_shopping_list_page(),
      ),
    );

    if (result == true) {
      _fetchLists(); // refresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Shopping Lists"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // ➕ knop
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openCreatePage,
                      child: const Icon(Icons.add),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Lijst weergave
                  Expanded(
                    child: shoppingLists.isEmpty
                        ? const Center(
                            child: Text("Nog geen lijsten aangemaakt"),
                          )
                        : ListView.builder(
                            itemCount: shoppingLists.length,
                            itemBuilder: (context, index) {
                              final list = shoppingLists[index];

                              return ListTile(
                                title: Text(list['list_name'] ?? ''),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ShoppingListDetailPage(
                                        listId: list['list_id'],
                                        listName: list['list_name'],
                                      ),
                                    ),
                                  );
                                },
                              );
                      }
                    )
                  ),
                ],
              ),
            ),
    );
  }
}

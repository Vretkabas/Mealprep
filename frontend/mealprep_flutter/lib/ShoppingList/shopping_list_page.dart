import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealprep_flutter/ShoppingList/create_shopping_list_page.dart';
import 'shopping_list_detail_page.dart';


class ShoppingListsPage extends StatefulWidget {
  const ShoppingListsPage({super.key});

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  final supabase = Supabase.instance.client;

  List<dynamic> shoppingLists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLists();
  }

  Future<void> _fetchLists() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final response = await supabase
        .from('shopping_lists')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      shoppingLists = response;
      _isLoading = false;
    });
  }

  Future<void> _openCreatePage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Create_shopping_list_page(userId: user.id),
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
                    child: ListView.builder(
                      itemCount: shoppingLists.length,
                      itemBuilder: (context, index) {
                        final list = shoppingLists[index];

                        return ListTile(
                          title: Text(list['list_name'] ?? ''),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ShoppingListDetailPage(
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

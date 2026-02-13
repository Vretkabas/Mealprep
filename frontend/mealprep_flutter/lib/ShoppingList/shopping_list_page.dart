import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealprep_flutter/ShoppingList/CreateShoppingListpage.dart';

class ShoppingListsPage extends StatefulWidget {
  const ShoppingListsPage({Key? key}) : super(key: key);

  @override
  State<ShoppingListsPage> createState() => _ShoppingListsPageState();
}

class _ShoppingListsPageState extends State<ShoppingListsPage> {
  final supabase = Supabase.instance.client;

  List<dynamic> _lists = [];
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
      _lists = response;
      _isLoading = false;
    });
  }

  Future<void> _openCreatePage() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateShoppingListPage(userId: user.id),
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
                      itemCount: _lists.length,
                      itemBuilder: (context, index) {
                        final list = _lists[index];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(list['list_name'] ?? ''),
                            subtitle: Text(
                              "Status: ${list['status']}",
                            ),
                            onTap: () {
                              // later: open details page
                            },
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

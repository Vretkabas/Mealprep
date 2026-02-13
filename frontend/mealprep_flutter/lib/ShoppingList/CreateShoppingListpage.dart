import 'package:flutter/material.dart';
import 'package:mealprep_flutter/services/shopping_list_service.dart';

class CreateShoppingListPage extends StatefulWidget {
  final String userId;

  const CreateShoppingListPage({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<CreateShoppingListPage> createState() =>
      _CreateShoppingListPageState();
}

class _CreateShoppingListPageState extends State<CreateShoppingListPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  bool _isLoading = false;

  Future<void> _createList() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await ShoppingListService.createList(
        userId: widget.userId,
        listName: _nameController.text.trim(),
      );

      if (!mounted) return;

      Navigator.pop(context, true); // terug met success
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fout bij aanmaken lijst: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nieuwe Boodschappenlijst'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Naam van de lijst',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vul een naam in';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createList,
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : const Text('Aanmaken'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

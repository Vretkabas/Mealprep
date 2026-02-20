import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../ShoppingList/shopping_list_page.dart';
import '../screens/barcode_scanner_screen.dart'; // Zorg dat dit pad klopt

class ProductCatalogPage extends StatefulWidget {
  final String storeName;

  const ProductCatalogPage({super.key, required this.storeName});

  @override
  State<ProductCatalogPage> createState() => _ProductCatalogPageState();
}

class _ProductCatalogPageState extends State<ProductCatalogPage> {
  // --- STATE VARIABELEN ---
  List<dynamic> products = [];
  bool _isLoading = true;
  int cartItemCount = 0;
  int _selectedIndex = 0; // Voor de Navbar

  // --- STYLING (Hetzelfde als HomePage) ---
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color textDark = const Color(0xFF345069);

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  // --- LOGICA ---

  Future<void> _fetchProducts() async {
    try {
      final response = await Dio().get(
        'https://jouw-api.com/products', // Vervang door je echte URL
        queryParameters: {'store': widget.storeName},
      );
      setState(() {
        products = response.data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Fout bij ophalen producten: $e");
    }
  }

  Future<void> _addToShoppingList(String productId) async {
    try {
      String activeListId = "jouw-actieve-lijst-uuid";
      String userId = "jouw-user-uuid";

      await Dio().post('https://jouw-api.com/shopping-list/add', data: {
        'user_id': userId,
        'list_id': activeListId,
        'product_id': productId,
        'quantity': 1,
      });

      setState(() {
        cartItemCount++;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Toegevoegd aan shopping list!")),
      );
    } catch (e) {
      print("Fout bij toevoegen: $e");
    }
  }

  // --- NAVBAR LOGICA ---
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShoppingListsPage()),
        );
        break;
      case 3:
        print("Navigeer naar Favorites");
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.storeName, style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black, size: 28),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShoppingListsPage()),
                  );
                },
              ),
              if (cartItemCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$cartItemCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  double price = product['price'] != null ? double.parse(product['price'].toString()) : 0.0;

                  return Card(
                    color: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: product['image_url'] != null
                                ? Image.network(product['image_url'], fit: BoxFit.contain)
                                : const Icon(Icons.image, size: 50, color: Colors.grey),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['product_name'] ?? 'Onbekend',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product['content'] ?? '',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "€${price.toStringAsFixed(2)}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: IconButton(
                                      constraints: const BoxConstraints(),
                                      padding: const EdgeInsets.all(6),
                                      icon: const Icon(Icons.shopping_cart, color: Colors.white, size: 20),
                                      onPressed: () => _addToShoppingList(product['product_id']),
                                    ),
                                  )
                                ],
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
      // --- DE NAVBAR  ---
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
}
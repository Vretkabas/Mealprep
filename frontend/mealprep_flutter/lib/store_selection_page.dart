import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'product_catalog_page.dart';
import '../screens/barcode_scanner_screen.dart';
import '../ShoppingList/shopping_list_page.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  int _selectedIndex = 0; // Staat op 0 omdat het onder 'Planning/Home' valt
  final Color brandGreen = const Color(0xFF00BFA5);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushNamed(context, '/home');
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (_) => const ShoppingListsPage()));
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
    final List<Map<String, String>> stores = [
      {'name': 'Delhaize', 'logo': 'assets/images/delhaize_logo.svg'},
      {'name': 'Carrefour', 'logo': 'assets/images/carrefour_logo.png'},
      {'name': 'Albert Heijn', 'logo': 'assets/images/ah_logo.jpg'},
      {'name': 'Jumbo', 'logo': 'assets/images/jumbo_logo.png'},
      {'name': 'Lidl', 'logo': 'assets/images/lidl_logo.png'},
      {'name': 'Colruyt', 'logo': 'assets/images/colruyt_logo.svg'}, 
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kies een winkel", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.85,
          ),
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final store = stores[index];
            final String logoPath = store['logo']!;
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductCatalogPage(storeName: store['name']!),
                  ),
                );
              },
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: logoPath.endsWith('.svg')
                            ? SvgPicture.asset(logoPath, fit: BoxFit.contain)
                            : Image.asset(logoPath, fit: BoxFit.contain),
                      ),
                      const SizedBox(height: 8),
                      Text(store['name']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
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
}
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
  int _selectedIndex = 0;
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color darkBlue = const Color(0xFF2C4A5E); 

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
      body: Stack(
        children: [
          // --- ACHTERGROND DESIGN ---
          Positioned(
            top: -100,
            right: -50,
            child: _buildBackgroundBlob(300, darkBlue.withOpacity(0.08)),
          ),
          Positioned(
            bottom: -50,
            left: -80,
            child: _buildBackgroundBlob(250, brandGreen.withOpacity(0.08)),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- CUSTOM HEADER ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Boodschappen doen?",
                        style: TextStyle(
                          fontSize: 16,
                          color: darkBlue.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Kies een winkel",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- GRID VAN WINKELS ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.95, // Iets hogere ratio voor meer ademruimte onderaan
                      ),
                      itemCount: stores.length,
                      itemBuilder: (context, index) {
                        final store = stores[index];
                        final String name = store['name']!;
                        final String logoPath = store['logo']!;

                        // Aangepaste schaling voor een gebalanceerd grid
                        double logoScale = 0.6; 
                        if (name == 'Colruyt') {
                          logoScale = 0.9; // Verlaagd van 1.9
                        } else if (name == 'Delhaize' || name == 'Albert Heijn') {
                          logoScale = 0.7; // Verlaagd van 1.4
                        }

                        return _buildStoreCard(context, name, logoPath, logoScale);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildStoreCard(BuildContext context, String name, String logoPath, double scale) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductCatalogPage(storeName: name),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0), // Extra padding binnen de kaart
                child: Center(
                  child: Transform.scale(
                    scale: scale,
                    child: logoPath.endsWith('.svg')
                        ? SvgPicture.asset(logoPath, fit: BoxFit.contain)
                        : Image.asset(logoPath, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF444444),
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundBlob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: brandGreen,
        unselectedItemColor: Colors.grey.shade400,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), activeIcon: Icon(Icons.camera_alt), label: "Scan"),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), activeIcon: Icon(Icons.list_alt_rounded), label: "Lists"),
          BottomNavigationBarItem(icon: Icon(Icons.star_border_rounded), activeIcon: Icon(Icons.star_rounded), label: "Favorites"),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: "Profile"),
        ],
      ),
    );
  }
}
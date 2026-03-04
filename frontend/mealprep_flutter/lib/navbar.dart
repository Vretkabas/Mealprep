import 'package:flutter/material.dart';
import 'barcode_scanner/barcode_scanner_screen.dart'; // pas imports aan
import 'shoppinglist/shopping_list_page.dart';

const Color brandGreen = Color(0xFF00BFA5); // pas aan naar jouw kleur

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavBar({super.key, required this.currentIndex});

  void _onItemTapped(BuildContext context, int index) {
    if (index == currentIndex) return; // Niet navigeren als je al op die pagina bent

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
        Navigator.pushNamed(context, '/favorites');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex < 0 ? 0 : currentIndex,
      onTap: (index) => _onItemTapped(context, index),
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: brandGreen,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.camera_alt_outlined), label: "Scan"),
        BottomNavigationBarItem(icon: Icon(Icons.list), label: "Lijsten"),
        BottomNavigationBarItem(icon: Icon(Icons.star_border), label: "Favorieten"),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: "Profiel"),
      ],
    );
  }
}
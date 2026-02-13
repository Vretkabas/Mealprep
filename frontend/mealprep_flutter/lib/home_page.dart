import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/barcode_scanner_screen.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Placeholder data (Later komt dit uit Supabase)
  String _userName = "John"; 
  int _scansThisWeek = 12;
  double _savedThisWeek = 45.00;
  int _healthScore = 78;

  int _selectedIndex = 0; // 0 = Home

  // Kleuren
  final Color brandGreen = const Color(0xFF00BFA5);
  final Color backgroundGrey = const Color(0xFFF5F7F9);
  final Color textDark = const Color(0xFF345069);

  // Navigatie logica voor de Bottom Bar
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Logica om naar andere pagina's te gaan
    switch (index) {
      case 0:
         print("Navigeer naar homepage");
         Navigator.pushNamed(context, '/home');
        break;
      case 1:
        // Scan pagina
        print("Navigeer naar Scan Pagina (via Navbar)");
        Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BarcodeScannerScreen(),
        ),
      );
        break;
      case 2:
        // Lists pagina
        print("Navigeer naar Lists");
        break;
      case 3:
        // Favorites pagina
        print("Navigeer naar Favorites");
        break;
      case 4:
        // Profile pagina
        print("Navigeer naar Profile");
        Navigator.pushNamed(context, '/profile');
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Alvast klaarzetten voor later
  }

  Future<void> _fetchUserData() async {
  final user = Supabase.instance.client.auth.currentUser;

  if (user != null) {
    try {
      // 1. Haal de naam op uit de 'profiles' tabel in de database
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        // We checken eerst de database, dan de metadata, en anders "User"
        _userName = data?['full_name'] ?? 
                    user.userMetadata?['full_name'] ?? 
                    user.userMetadata?['display_name'] ?? 
                    "User";
      });
    } catch (e) {
      print("Fout bij ophalen naam: $e");
    }
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER SECTIE ---
              Row(
                children: [
                  const Icon(Icons.waving_hand, color: Colors.amber, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    "Hi, $_userName!", 
                    style: TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold, 
                      color: textDark
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                "How are you shopping today?",
                style: TextStyle(fontSize: 14, color: textDark.withOpacity(0.6)),
              ),
              const SizedBox(height: 30),

              // --- MAIN ACTION CARDS ---
              
              // 1. In Store (Groen)
              _buildActionCard(
                title: "In Store",
                subtitle: "Scan products now",
                icon: Icons.camera_alt_outlined,
                color: brandGreen,
                textColor: Colors.white,
                isPrimary: true,
                onTap: () {
                  print("Navigeer naar Scan Pagina (via Card)");
                   Navigator.pushNamed(context, '/scan');
                },
              ),
              const SizedBox(height: 20),

              // 2. Planning (Wit)
              _buildActionCard(
                title: "Planning",
                subtitle: "Browse deals from home",
                icon: Icons.assignment_outlined,
                color: Colors.white,
                textColor: textDark,
                isPrimary: false,
                onTap: () {
                  print("Navigeer naar Planning");
                },
              ),
              const SizedBox(height: 20),

              // 3. My Lists (Wit)
              _buildActionCard(
                title: "My Lists",
                subtitle: "View your shopping lists",
                icon: Icons.checklist_rtl_sharp,
                color: Colors.white,
                textColor: textDark,
                isPrimary: false,
                onTap: () {
                  print("Navigeer naar Lists");
                },
              ),

              const SizedBox(height: 40),

              // --- STATS SECTIE (THIS WEEK) ---
              Text(
                "THIS WEEK",
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w900, 
                  color: textDark,
                  letterSpacing: 1.0,
                  shadows: [Shadow(color: Colors.grey.withOpacity(0.5), blurRadius: 2, offset: const Offset(1,1))]
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard(_scansThisWeek.toString(), "scans", Colors.greenAccent.withOpacity(0.1), brandGreen),
                  const SizedBox(width: 12),
                  _buildStatCard("€${_savedThisWeek.toInt()}", "saved", Colors.blueAccent.withOpacity(0.1), Colors.blue),
                  const SizedBox(width: 12),
                  _buildStatCard(_healthScore.toString(), "Health", Colors.purpleAccent.withOpacity(0.1), Colors.purple),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      
      // --- BOTTOM NAVIGATION BAR ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Zorgt dat alle 5 iconen zichtbaar zijn
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

  // --- WIDGET BUILDERS ---

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color textColor,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100, // Vaste hoogte voor uniformiteit
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          children: [
            // Icoon links
            Icon(icon, size: 32, color: textColor),
            const SizedBox(width: 15),
            
            // Tekst midden
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),

            // Pijl Button rechts
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black, // Zwarte cirkel zoals in design
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward,
                color: isPrimary ? brandGreen : Colors.white, // Groene pijl bij groene kaart, wit bij witte
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color bg, Color textCol) {
    return Container(
      width: 100, 
      height: 100,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
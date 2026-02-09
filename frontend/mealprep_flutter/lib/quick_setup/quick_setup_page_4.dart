import 'package:flutter/material.dart';
import '../home_page.dart';

class QuickSetupPage4 extends StatefulWidget {
  const QuickSetupPage4({super.key});

  @override
  State<QuickSetupPage4> createState() => _QuickSetupPage4State();
}

class _QuickSetupPage4State extends State<QuickSetupPage4> {
  // Lijst van geselecteerde allergieën/voorkeuren
  final Set<String> _selectedItems = {};

  // GDPR State
  bool _gdprConsent = false;
  bool _showGdprError = false;

  final Color brandGreen = const Color(0xFF00BFA5);
  final Color backgroundGrey = const Color(0xFFF5F7F9);
  final Color textDark = const Color(0xFF345069);

  // De lijst met opties inclusief "None"
  final List<Map<String, dynamic>> _options = [
    {'label': 'Nuts', 'icon': '🥜'},
    {'label': 'Gluten', 'icon': '🌾'},
    {'label': 'Lactose', 'icon': '🥛'},
    {'label': 'Fish', 'icon': '🐟'},
    {'label': 'Vegetarian', 'icon': '🌱'},
    {'label': 'Vegan', 'icon': '🌿'},
    {'label': 'None', 'icon': '✅'}, // De "Geen" optie
  ];

  void _handleSelection(String label) {
    setState(() {
      if (label == 'None') {
        // Als 'None' wordt gekozen, wis alle andere selecties
        _selectedItems.clear();
        _selectedItems.add('None');
      } else {
        // Als een specifieke allergie wordt gekozen, verwijder 'None'
        _selectedItems.remove('None');
        if (_selectedItems.contains(label)) {
          _selectedItems.remove(label);
        } else {
          _selectedItems.add(label);
        }
      }
    });
  }

  void _finishSetup() {
    // Check of er iets gekozen is (minstens 1 allergie of 'None')
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecteer aub je allergieën of kies 'None'.")),
      );
      return;
    }

    // Strikte GDPR Check
    if (!_gdprConsent) {
      setState(() => _showGdprError = true);
      return;
    }

    print("Definitieve selectie: $_selectedItems");

    // --- NAVIGATIE NAAR HOME ---
    // pushAndRemoveUntil zorgt ervoor dat je niet terug kan klikken naar de setup
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false, 
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundGrey,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // Progress Bar (100%)
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                child: Container(decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 30),

              Text("Allergies & Preferences", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 10),
              const Text("🥗", style: TextStyle(fontSize: 50)),
              const SizedBox(height: 20),

              // Grid van keuzes
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                  ),
                  itemCount: _options.length,
                  itemBuilder: (context, index) {
                    final item = _options[index];
                    final bool isSelected = _selectedItems.contains(item['label']);
                    return _buildSelectionCard(item['label'], item['icon'], isSelected);
                  },
                ),
              ),

              // GDPR BOX
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _showGdprError ? Colors.red.withOpacity(0.05) : Colors.white,
                  border: Border.all(color: _showGdprError ? Colors.red : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    "Ik geef toestemming voor het verwerken van deze gegevens.",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  activeColor: brandGreen,
                  value: _gdprConsent,
                  onChanged: (val) => setState(() {
                    _gdprConsent = val ?? false;
                    _showGdprError = false;
                  }),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),

              const SizedBox(height: 20),

              // Finish Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _finishSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text("Finish", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(String label, String emoji, bool isSelected) {
    return GestureDetector(
      onTap: () => _handleSelection(label),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? brandGreen.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? brandGreen : Colors.transparent, width: 2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 4),
            Text(
              label == 'None' ? 'No Allergies' : label, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                color: isSelected ? brandGreen : textDark,
                fontSize: 14
              )
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

class QuickSetupPage3 extends StatefulWidget {
  const QuickSetupPage3({super.key});

  @override
  State<QuickSetupPage3> createState() => _QuickSetupPage3State();
}

class _QuickSetupPage3State extends State<QuickSetupPage3> {
  // 0 = Low, 1 = Slightly, 2 = Medium, 3 = Very active
  int? _selectedActivityLevel;
  
  // GDPR State (Strikt)
  bool _gdprConsent = false;
  bool _showGdprError = false;

  final Color brandGreen = const Color(0xFF00BFA5);
  final Color backgroundGrey = const Color(0xFFF5F7F9);
  final Color textDark = const Color(0xFF345069);

  void _goToNextPage() {
    // 1. GDPR Check (Strikt)
    if (!_gdprConsent) {
      setState(() {
        _showGdprError = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Toestemming vereist voor verwerking van activiteitsdata."),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 2. Selectie Check
    if (_selectedActivityLevel != null) {
      print("Gekozen activiteit: $_selectedActivityLevel");
      print("GDPR Consent (Activity): $_gdprConsent");

      // TODO: Navigeer naar de volgende pagina (bijv. Dashboard of Resultaat)
      Navigator.pushNamed(context, '/quick_setup_4');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Activiteit opgeslagen! (Klaar voor volgende stap)")),
      );
    } 
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // --- Progress Bar (75%) ---
              const SizedBox(height: 10),
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.75, // 3de stap van de 4 (of 3)
                  child: Container(decoration: BoxDecoration(color: brandGreen, borderRadius: BorderRadius.circular(3))),
                ),
              ),
              const SizedBox(height: 30),

              // --- Titel & Afbeelding ---
              Text(
                "How active are you?",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Placeholder voor de rennende persoon afbeelding
              // Gebruik hier je eigen asset: Image.asset('assets/images/runner.png', height: 100),
              Icon(Icons.directions_run, size: 80, color: Colors.amber[700]), 
              const SizedBox(height: 30),

              // --- Activiteit Opties ---
              _buildActivityCard(0, "Low", "Almost no activity"),
              const SizedBox(height: 15),
              _buildActivityCard(1, "Slightly active", "1-3 times sport a week"),
              const SizedBox(height: 15),
              _buildActivityCard(2, "Medium", "3-5 times sport a week"),
              const SizedBox(height: 15),
              _buildActivityCard(3, "Very active", "6-7 times sport a week"),

              const SizedBox(height: 30),

              // --- GDPR Check (Strikt) ---
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _showGdprError ? Colors.red.withOpacity(0.05) : Colors.white,
                  border: Border.all(color: _showGdprError ? Colors.red : Colors.transparent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  title: const Text(
                    "Ik begrijp dat mijn activiteitsniveau wordt gebruikt om mijn caloriebehoefte te berekenen.",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    "Deze gegevens worden verwerkt volgens onze strikte privacyvoorwaarden.",
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  activeColor: brandGreen,
                  value: _gdprConsent,
                  onChanged: (val) {
                    setState(() {
                      _gdprConsent = val ?? false;
                      _showGdprError = false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              
              const SizedBox(height: 30),

              // --- Next Button ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedActivityLevel == null ? null : _goToNextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen,
                    disabledBackgroundColor: brandGreen.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 5,
                  ),
                  child: const Text("Next", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityCard(int index, String title, String subtitle) {
    final bool isSelected = _selectedActivityLevel == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedActivityLevel = index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? brandGreen : Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 5)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:mealprep_flutter/quick_setup/quick_setup_data.dart';  // save all choices in this object then to backend

class QuickSetupPage1 extends StatefulWidget {
  const QuickSetupPage1({super.key});

  @override
  State<QuickSetupPage1> createState() => _QuickSetupPage1State();
}

class _QuickSetupPage1State extends State<QuickSetupPage1> {
  // We houden bij welke optie is geselecteerd.
  // 0 = Lose Weight, 1 = Maintain, 2 = Gain
  int? _selectedOption;

  final Color brandGreen = const Color(0xFF00BFA5);
  final Color darkText = const Color(0xFF345069);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: darkText),
          onPressed: () {
             // In een onboarding wil je misschien niet terug naar register, 
             // maar voor nu is pop prima.
             Navigator.pop(context); 
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // --- PROGRESS BAR (25%) ---
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: 0.25, // 1 van de 4 stappen = 25%
                  minHeight: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(brandGreen),
                ),
              ),
              const SizedBox(height: 30),

              // --- TITEL & HERO ICON ---
              Text(
                "What is your goal?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 20),
              
              // Target Icon (gebruik hier jouw asset of een Icon als placeholder)
              Icon(Icons.track_changes, size: 80, color: Colors.redAccent),
              // Als je de image hebt: 
              // Image.asset('assets/images/target_icon.png', height: 100),

              const SizedBox(height: 40),

              // --- KEUZE OPTIES ---
              _buildOptionCard(0, "Lose Weight", Icons.trending_down, Colors.redAccent),
              const SizedBox(height: 15),
              _buildOptionCard(1, "Maintain Weight", Icons.balance, Colors.orangeAccent),
              const SizedBox(height: 15),
              _buildOptionCard(2, "Gain Weight", Icons.trending_up, Colors.green),

              const Spacer(),

              // --- NEXT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _selectedOption == null 
                      ? null // Knop is uitgeschakeld als niks is gekozen
                      : () {
                          print("Gekozen doel: $_selectedOption");
                          // save data in object
                          final data = QuickSetupData();
                          data.goal = _selectedOption;
                          Navigator.pushNamed(context, '/quick_setup_2', arguments: data);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandGreen, // De groene kleur uit je design
                    disabledBackgroundColor: brandGreen.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Een herbruikbare widget voor de keuzekaarten
  Widget _buildOptionCard(int index, String text, IconData icon, Color iconColor) {
    final bool isSelected = _selectedOption == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedOption = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected 
              ? Border.all(color: brandGreen, width: 2) // Groene rand als geselecteerd
              : Border.all(color: Colors.transparent, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icoontje links (met lichte achtergrond)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(width: 20),
            // Tekst
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: darkText,
              ),
            ),
            const Spacer(),
            // Vinkje als geselecteerd (optioneel, maar mooi voor UX)
            if (isSelected)
              Icon(Icons.check_circle, color: brandGreen),
          ],
        ),
      ),
    );
  }
}
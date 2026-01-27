import 'package:flutter/material.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Kleuren uit de afbeelding (groene tinten)
    final Color appBackground = const Color(0xFFE8ECEF);
    final Color brandGreen = const Color(0xFF00BFA5); // Een mooie teal/groen kleur
    final Color textDark = const Color(0xFF345069);

    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context), // Terug naar login
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- LOGO GEDEELTE (Groene Variant) ---
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0F0C0).withOpacity(0.5), // Lichtgroene achtergrond
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Image.asset(
                      'assets/images/Logo2_mealprep.jpg',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(Icons.person_add, size: 60, color: brandGreen);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "MealPrep",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: brandGreen, // Groene tekst zoals in de afbeelding
                ),
              ),

              const SizedBox(height: 40),

              // --- INPUT VELDEN ---
              _buildTextField("Username", false, textDark),
              const SizedBox(height: 20),
              _buildTextField("Email", false, textDark),
              const SizedBox(height: 20),
              _buildTextField("Password", true, textDark),
              const SizedBox(height: 20),
              _buildTextField("Confirm Password", true, textDark),

              const SizedBox(height: 50),

              // --- REGISTREER KNOP ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    // Hier komt later de registratie logica
                    print("Registreren...");
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: textDark,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Register",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Hulpfunctie om snel velden te maken
  Widget _buildTextField(String hint, bool isPassword, Color color) {
    return TextField(
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: color.withOpacity(0.8), 
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: color, width: 2),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.green, width: 2),
        ),
      ),
    );
  }
}
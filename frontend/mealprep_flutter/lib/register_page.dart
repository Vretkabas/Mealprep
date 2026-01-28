import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers om de tekst uit de velden te halen
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Functie voor de popups
  void _showPopup(String title, String message, {bool success = false}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (success) Navigator.of(context).pop(); // Terug naar login na succes
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      _showPopup("Fout", "Wachtwoorden komen niet overeen.");
      return;
    }

    try {
      // Dio aanroep naar je backend (IP uit main.dart gebruiken)
      final dio = Dio(BaseOptions(baseUrl: 'http://10.0.2.2')); // Verander naar jouw server IP
      
      final response = await dio.post('/register', data: {
        "username": _usernameController.text,
        "email": _emailController.text,
        "password": _passwordController.text, // De backend moet dit hashen met Bcrypt!
      });

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showPopup("Succes", "Je bent succesvol geregistreerd!", success: true);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        _showPopup("Account bestaat al", "Dit e-mailadres is al geregistreerd.");
      } else {
        _showPopup("Fout", "Er is iets misgegaan: ${e.message}");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color appBackground = const Color(0xFFE8ECEF);
    final Color brandGreen = const Color(0xFF00BFA5);
    final Color textDark = const Color(0xFF345069);

    return Scaffold(
      backgroundColor: appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textDark),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            children: [
              // Logo sectie (ongewijzigd)
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(color: const Color(0xFFD0F0C0).withOpacity(0.5), shape: BoxShape.circle),
                child: ClipOval(child: Padding(padding: const EdgeInsets.all(25.0), child: Image.asset('assets/images/Logo2_mealprep.jpg', fit: BoxFit.contain))),
              ),
              const SizedBox(height: 10),
              Text("MealPrep", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandGreen)),
              const SizedBox(height: 40),

              // Input velden met controllers
              _buildTextField("Username", false, textDark, _usernameController),
              const SizedBox(height: 20),
              _buildTextField("Email", false, textDark, _emailController),
              const SizedBox(height: 20),
              _buildTextField("Password", true, textDark, _passwordController),
              const SizedBox(height: 20),
              _buildTextField("Confirm Password", true, textDark, _confirmPasswordController),

              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, bool isPassword, Color color, TextEditingController controller) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: color, width: 2)),
      ),
    );
  }
}
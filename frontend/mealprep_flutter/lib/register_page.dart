import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// get supabase client
final supabase = Supabase.instance.client;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // Loading state om te laten zien dat we bezig zijn
  bool _isLoading = false;

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
              if (success && mounted) Navigator.of(context).pop(); 
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _register() async {
    // Validation
    if (_passwordController.text != _confirmPasswordController.text) {
      _showPopup("Fout", "Wachtwoorden komen niet overeen.");
      return;
    }

    // Zet laden aan (UI update)
    setState(() {
      _isLoading = true;
    });

    try {
      print("--- START REGISTRATIE MET SUPABASE ---");

      // =============================================
      // supabase signup function
      // =============================================
      final response = await supabase.auth.signUp(
        email: _emailController.text.trim(),      // .trim() remove spaces
        password: _passwordController.text,
        data: {
          'username': _usernameController.text,   // saved in user_metadata
        },
      );

      // =============================================
      // Check result
      // =============================================
      // response.user contains user info if successful
      if (!mounted) return;

      if (response.user != null) {
        print("Succes! User ID: ${response.user!.id}");
        print("Email: ${response.user!.email}");

        // go to next page
        Navigator.pushReplacementNamed(context, '/quick_setup_1');
      } else {
        // happens if email confirmation is required
        _showPopup(
          "Check je email",
          "We hebben een bevestigingslink gestuurd naar ${_emailController.text}",
          success: true,
        );
      }

    // =============================================
    // error handling
    // =============================================
    } on AuthException catch (e) {
      print("AUTH ERROR: ${e.message}");

      // supabase shows error messages directly in e.message
      _showPopup("Registratie mislukt", e.message);

    } catch (e) {
      // other error (network issues, etc)
      print("ONBEKENDE FOUT: $e");
      _showPopup("Fout", "Er ging iets mis. Probeer het opnieuw.");
    } finally {
      // turn off loading (UI update)
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
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
              // Logo
              Container(
                width: 160, height: 160,
                decoration: BoxDecoration(color: const Color(0xFFD0F0C0).withOpacity(0.5), shape: BoxShape.circle),
                child: ClipOval(child: Padding(padding: const EdgeInsets.all(25.0), child: Image.asset('assets/images/Logo2_mealprep.jpg', fit: BoxFit.contain))),
              ),
              const SizedBox(height: 10),
              Text("MealPrep", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: brandGreen)),
              const SizedBox(height: 40),

              // Inputs
              _buildTextField("Username", false, textDark, _usernameController),
              const SizedBox(height: 20),
              _buildTextField("Email", false, textDark, _emailController),
              const SizedBox(height: 20),
              _buildTextField("Password", true, textDark, _passwordController),
              const SizedBox(height: 20),
              _buildTextField("Confirm Password", true, textDark, _confirmPasswordController),

              const SizedBox(height: 50),

              // Register Button met Laad-indicator
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register, // Knop uit als we laden
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: textDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
                      )
                    : const Text("Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
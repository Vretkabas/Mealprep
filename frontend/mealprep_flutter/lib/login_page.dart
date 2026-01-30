import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Supabase client ophalen (al geïnitialiseerd in main.dart)
final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // loading state for button
  bool _isLoading = false;

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Inloggen mislukt"),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _login() async {
    // =============================================
    // turn on loading
    // =============================================
    setState(() {
      _isLoading = true;
    });

    try {
      print("--- START LOGIN MET SUPABASE ---");

      // =============================================
      // signinwithpassword function
      // =============================================
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // =============================================
      // get result
      // =============================================
      if (!mounted) return;

      if (response.user != null) {
        print("Login success! User ID: ${response.user!.id}");
        print("Email: ${response.user!.email}");

        // Session contains JWT token (automatically saved by Supabase)
        print("Session token: ${response.session?.accessToken}");

        // Show success message
        // TODO: Replace with navigation to home page later
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Login Successful"),
            content: Text("Welcome back, ${response.user!.email}!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("OK"),
              ),
            ],
          ),
        );
      }

    // =============================================
    // Error handling
    // =============================================
    } on AuthException catch (e) {
      print("AUTH ERROR: ${e.message}");

      _showError(e.message);

    } catch (e) {
      print("ONBEKENDE FOUT: $e");
      _showError("Er ging iets mis. Probeer het opnieuw.");
    } finally {
      // turn off loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF345069);
    
    return Scaffold(
      body: Stack(
        children: [
          // Achtergrond clippers (ongewijzigd)
          Positioned(top: 0, left: 0, right: 0, height: 220, child: ClipPath(clipper: TopWaveClipper(), child: Container(color: darkBlue))),
          Positioned(bottom: 0, left: 0, right: 0, height: 200, child: ClipPath(clipper: BottomWaveClipper(), child: Container(color: darkBlue))),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  children: [
                    // Logo (ongewijzigd)
                    Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(color: Colors.grey[300]?.withOpacity(0.9), shape: BoxShape.circle),
                      child: ClipOval(child: Padding(padding: const EdgeInsets.all(20.0), child: Image.asset('assets/images/Logo_mealprep.jpg', fit: BoxFit.contain))),
                    ),
                    const SizedBox(height: 60),

                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person, color: darkBlue),
                        hintText: "Email",
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: darkBlue),
                        hintText: "Password",
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkBlue, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Login button with loading state
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _login,  // disable button when loading
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildButton("Register", darkBlue, () {
                      Navigator.pushNamed(context, '/register');
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black87, elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- CLIPPERS (Design behouden) ---

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.25, size.height * 1.0, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.75, size.height * 0.8, size.width, size.height * 0.5);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
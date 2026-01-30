import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

String _getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8081';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:8081';
  } else {
    return 'http://localhost:8081';
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

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
    try {
      final dio = Dio(BaseOptions(baseUrl: _getBaseUrl()));
      final response = await dio.post('/login', data: {
        "email": _emailController.text,
        "password": _passwordController.text,
      });

      if (response.statusCode == 200) {
        // Hier krijg je normaal een JWT token terug
        // Voor nu: ga naar de volgende pagina
        print("Token: ${response.data['token']}");
        // Navigator.pushNamed(context, '/quicksetup'); // Komt later
      }
    } on DioException catch (e) {
      _showError("Ongeldige e-mail of wachtwoord.");
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

                    _buildButton("Login", darkBlue, _login),
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
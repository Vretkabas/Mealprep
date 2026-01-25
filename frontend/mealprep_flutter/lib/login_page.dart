import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MealPrep Login',
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFE8ECEF),
        primarySwatch: Colors.blueGrey,
      ),
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final Color darkBlue = const Color(0xFF345069);
    
    return Scaffold(
      // ResizeToAvoidBottomInset voorkomt dat de layout verspringt bij het toetsenbord
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // --- 1. ACHTERGROND (DE WOLKEN) ---
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(color: darkBlue),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 200,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(color: darkBlue),
            ),
          ),

          // --- 2. DE INHOUD (LOGO & INPUTS) ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40), // Iets meer ruimte aan de bovenkant
                    
                    // Logo Container (VERGROOT)
                    Container(
                      width: 200, // Was 130
                      height: 200, // Was 130
                      decoration: BoxDecoration(
                        color: Colors.grey[300]?.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 15, // Iets zachtere schaduw
                            spreadRadius: 2,
                          )
                        ],
                      ),
                      child: ClipOval(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0), // Padding aangepast voor groter logo
                          child: Image.asset(
                            'assets/images/Logo_mealprep.jpg',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(Icons.restaurant, size: 80, color: darkBlue);
                            },
                          ),
                        ),
                      ),
                    ),
                    
                    // De "MealPrep" tekst is hier VERWIJDERD.

                    const SizedBox(height: 60), // Ruimte tussen logo en inputs

                    // Email veld
                    TextField(
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person, color: darkBlue),
                        hintText: "Email",
                        hintStyle: TextStyle(color: darkBlue.withOpacity(0.7), fontWeight: FontWeight.bold),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkBlue, width: 2)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Password veld
                    TextField(
                      obscureText: true,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.lock_outline, color: darkBlue),
                        hintText: "Password",
                        hintStyle: TextStyle(color: darkBlue.withOpacity(0.7), fontWeight: FontWeight.bold),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: darkBlue, width: 2)),
                      ),
                    ),

                    const SizedBox(height: 60),

                    // Knoppen
                    _buildButton("Login", darkBlue),
                    const SizedBox(height: 20),
                    _buildButton("Register", darkBlue),
                    
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// --- CLIPPERS VOOR DE WOLKEN (Ongewijzigd) ---
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
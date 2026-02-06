import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';


import 'login_page.dart'; 
import 'register_page.dart';

// import 'screens/home_screen.dart'; // Deze heb ik even uitgezet omdat HomeScreen ook onderin dit bestand staat
import 'screens/barcode_scanner_screen.dart';
import 'screens/camera_scan_screen.dart';
import 'quick_setup/quick_setup_page_1.dart';
import 'quick_setup/quick_setup_page_2.dart';
import 'quick_setup/quick_setup_page_3.dart';
import 'quick_setup/quick_setup_page_4.dart';

// ===============================
//  Setup Dio (HTTP Client)
// ===============================
final dioProvider = Provider<Dio>((ref) {
  String baseUrl;

  if (kIsWeb) {
    baseUrl = 'http://localhost';
  } else if (Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2';
  } else {
    baseUrl = 'http://localhost';
  }

  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
    ),
  );
});

// ===============================
//  Backend test provider
// ===============================
final apiCheckProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/mini-test');
    return response.data.toString();
  } catch (e) {
    return "Fout bij verbinden: $e";
  }
});

// ===============================
// App start
// ===============================
void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Promo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),

      // Startscherm (Dit is nu nog HomeScreen voor de test)
      home: const HomeScreen(),

      //  Routes
      routes: {
        '/scan': (_) => const BarcodeScannerScreen(),
        '/camera': (_) => const CameraScanScreen(),
        // NIEUWE ROUTE TOEGEVOEGD:
        '/login': (_) => const LoginPage(), 
        '/register': (_) => const RegisterPage(),
        '/quick_setup_1': (_) => const QuickSetupPage1(), 
        '/quick_setup_2': (_) => const QuickSetupPage2(),
        '/quick_setup_3': (_) => const QuickSetupPage3(),
        '/quick_setup_4': (_) => const QuickSetupPage4(),
      },
    );
  }
}

// ===============================
// HomeScreen
// ===============================
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiStatus = ref.watch(apiCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Promo Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: SingleChildScrollView( // Scroll view toegevoegd voor kleine schermen
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shopping_cart, size: 80, color: Colors.green),
              const SizedBox(height: 20),
          
              const Text(
                "Backend Status:",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
          
              const SizedBox(height: 10),
          
              apiStatus.when(
                data: (data) => Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(data, textAlign: TextAlign.center),
                ),
                error: (err, _) => Text(
                  "Error: $err",
                  style: const TextStyle(color: Colors.red),
                ),
                loading: () => const CircularProgressIndicator(),
              ),
          
              const SizedBox(height: 20),
          
              // Test backend opnieuw
              ElevatedButton(
                onPressed: () => ref.refresh(apiCheckProvider),
                child: const Text("Test Verbinding Opnieuw"),
              ),
          
              const SizedBox(height: 20),
          
              //  START SCAN FLOW
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Scan product"),
                onPressed: () {
                  Navigator.pushNamed(context, '/scan');
                },
              ),
              
              const SizedBox(height: 40),
              const Divider(),
              const SizedBox(height: 10),
          
              // ============================================
              //  TIJDELIJKE NAVIGATIE NAAR LOGIN PAGINA
              // ============================================
              const Text("Tijdelijke Navigatie:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 10),
              
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey, // Opvallende kleur
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
                icon: const Icon(Icons.login),
                label: const Text("Ga naar Login Design"),
                onPressed: () {
                  // Hiermee ga je naar de nieuwe login pagina
                  Navigator.pushNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
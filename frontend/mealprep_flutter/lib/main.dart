import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import 'login_page.dart'; 
import 'home_page.dart';
import 'register_page.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/camera_scan_screen.dart';
import 'quick_setup/quick_setup_page_1.dart';
import 'quick_setup/quick_setup_page_2.dart';
import 'quick_setup/quick_setup_page_3.dart';
import 'quick_setup/quick_setup_page_4.dart';

// ===============================
//  Setup Dio (HTTP Client - behouden voor toekomstig gebruik)
// ===============================
final dioProvider = Provider<Dio>((ref) {
  String baseUrl;

  if (kIsWeb) {
    baseUrl = 'http://localhost:8081';
  } else if (Platform.isAndroid) {
    baseUrl = 'http://10.0.2.2:8081';
  } else {
    baseUrl = 'http://localhost:8081';
  }

  return Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
    ),
  );
});

// ===============================
//  Supabase Initialization
// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://drodrhsvrybrvjlvihxk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyb2RyaHN2cnlicnZqbHZpaHhrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg4ODc1ODEsImV4cCI6MjA4NDQ2MzU4MX0.BV7krCsVbGUXjqFgwroA6Jr3MhcYui0gSwR1ftCPT9Y',
  );
  
  runApp(const ProviderScope(child: MyApp()));
}

// Global accessor for Supabase client
final supabase = Supabase.instance.client;

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

      // ===============================================
      // START DE APP DIRECT OP DE LOGIN PAGINA
      // ===============================================
      home: const LoginPage(),

      //  Routes definities
      routes: {
        '/scan': (_) => const BarcodeScannerScreen(),
        '/camera': (_) => const CameraScanScreen(),
        '/login': (_) => const LoginPage(), 
        '/home': (_) => const HomePage(),
        '/register': (_) => const RegisterPage(),
        '/quick_setup_1': (_) => const QuickSetupPage1(), 
        '/quick_setup_2': (_) => const QuickSetupPage2(),
        '/quick_setup_3': (_) => const QuickSetupPage3(),
        '/quick_setup_4': (_) => const QuickSetupPage4(),
      },
    );
  }
}
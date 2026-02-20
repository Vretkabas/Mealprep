import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'login_page.dart';
import 'home_page.dart';
import 'register_page.dart';
import 'settings/profile_page.dart';
import 'screens/barcode_scanner_screen.dart';
import 'screens/camera_scan_screen.dart';
import 'quick_setup/quick_setup_page_1.dart';
import 'quick_setup/quick_setup_page_2.dart';
import 'quick_setup/quick_setup_page_3.dart';
import 'quick_setup/quick_setup_page_4.dart';
import 'store_selection_page.dart';

// ===============================
// Setup Dio
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
      receiveTimeout: const Duration(seconds: 5),
    ),
  );
});

// ===============================
// Main Initialisatie
// ===============================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  

  // Initialiseer Env & Supabase
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_KEY']!,
  );

  runApp(
    const ProviderScope(child: MyApp()),
  );
}

final supabase = Supabase.instance.client;

final apiCheckProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    final response = await dio.get('/');
    return response.data.toString();
  } catch (e) {
    return "Fout bij verbinden: $e";
  }
});

// ===============================
// App Start
// ===============================
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

      home: const LoginPage(),

      routes: {
        '/scan': (_) => const BarcodeScannerScreen(),
        '/camera': (_) => const CameraScanScreen(),
        '/login': (_) => const LoginPage(), 
        '/home': (_) => const HomePage(),
        '/profile': (_) => const ProfilePage(),
        '/register': (_) => const RegisterPage(),
        '/quick_setup_1': (_) => const QuickSetupPage1(), 
        '/quick_setup_2': (_) => const QuickSetupPage2(),
        '/quick_setup_3': (_) => const QuickSetupPage3(),
        '/quick_setup_4': (_) => const QuickSetupPage4(),
        '/store_selection': (_) => const StoreSelectionPage(),
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'dart:io'; // for Platform check
import 'package:flutter/foundation.dart'; // for kIsWeb

import 'screens/home_screen.dart';

// Setup Dio (HTTP Client)
final dioProvider = Provider<Dio>((ref) {
  String baseUrl;

  if (kIsWeb) {
    // check if in browser
    baseUrl = 'http://localhost'; 
  } else if (Platform.isAndroid) {
    // check android emulator
    baseUrl = 'http://10.0.2.2'; 
  } else {
    // IOS simulator or other
    baseUrl = 'http://localhost'; 
  }

  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 5),
  ));
  return dio;
});

// retrieve test data
final apiCheckProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    // call endpoint
    final response = await dio.get('/mini-test');
    return response.data.toString();
  } catch (e) {
    return "Fout bij verbinden: $e";
  }
});

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(),
    );
  }
}
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FoodApiService {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8081';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:8081';
    } else {
      return 'http://localhost:8081';
    }
  }

  static Future<Map<String, dynamic>> fetchByBarcode(String barcode) async {
    try {
      final url = '$baseUrl/food/barcode/$barcode';
      print('Fetching product from: $url'); // Debug log
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 5));

      print('Response status: ${response.statusCode}'); // Debug log
      print('Response body: ${response.body}'); // Debug log

      if (response.statusCode == 404) {
        throw Exception('Product met barcode $barcode niet gevonden');
      }

      if (response.statusCode != 200) {
        throw Exception('Fout bij ophalen product: ${response.statusCode}');
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('Error fetching product: $e');
      rethrow;
    }
  }
}
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';


class FoodApiService {
  static const String baseUrl = 'http://10.0.2.2:8081'; // voor Android emulator (localhost voor ios gebruiken)
  
  static Future<Map<String, dynamic>> fetchByBarcode(
    String barcode, {
    String? userId,
    bool logScan = true,
    bool allowDuplicates = false,
    int duplicateWindowMinutes = 1440, // 24 uur
  }) async {
    try {
      // Bouw URL met query parameters
      var uri = Uri.parse('$baseUrl/food/barcode/$barcode').replace(
        queryParameters: {
          if (userId != null) 'user_id': userId,
          'log_scan': logScan.toString(),
          'allow_duplicates': allowDuplicates.toString(),
          'duplicate_window_minutes': duplicateWindowMinutes.toString(),
        },
      );
      
      print('Fetching product from: $uri');
      
      final response = await http.get(uri);
      
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Log scan status voor debugging
        if (data['scan_logged'] == true) {
          print('Scan logged to database');
        } else {
          print('Scan NOT logged - reason: ${data['scan_status']}');
        }
        
        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Product niet gevonden');
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching product: $e');
      rethrow;
    }
  }
}
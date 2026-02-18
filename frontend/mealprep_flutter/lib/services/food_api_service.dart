import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodApiService {
  static const String baseUrl = 'http://10.0.2.2:8081'; // voor Android emulator (localhost voor ios gebruiken)

  static Future<Map<String, dynamic>> fetchByBarcode(
    String barcode, {
    bool logScan = true,
    bool allowDuplicates = false,
    int duplicateWindowMinutes = 1440, // 24 uur
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final token = session?.accessToken;

      if (token == null) {
        throw Exception("User not authenticated");
      }

      var uri = Uri.parse('$baseUrl/food/barcode/$barcode').replace(
        queryParameters: {
          'log_scan': logScan.toString(),
          'allow_duplicates': allowDuplicates.toString(),
          'duplicate_window_minutes': duplicateWindowMinutes.toString(),
        },
      );

      print('Fetching product from: $uri');
      print('Using token: $token');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['scan_logged'] == true) {
          print('Scan logged to database');
        } else {
          print('Scan NOT logged - reason: ${data['scan_status']}');
        }

        return data;
      } else if (response.statusCode == 404) {
        throw Exception('Product niet gevonden');
      } else if (response.statusCode == 401) {
        throw Exception('Niet geautoriseerd - controleer login');
      } else {
        throw Exception('Failed to load product: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching product: $e');
      rethrow;
    }
  }
}

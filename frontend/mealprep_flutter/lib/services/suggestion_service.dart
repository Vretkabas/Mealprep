import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SuggestionService {
  static String get _baseUrl {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:8081';
  }

  static Future<Map<String, dynamic>> getPromotionSuggestions({
    required String storeName,
    required List<String> scannedProducts,
  }) async {
    // Haal Supabase JWT token op
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('Niet ingelogd');

    final response = await http.post(
      Uri.parse('$_baseUrl/suggestions/promotions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.accessToken}', // ✅ JWT token
      },
      body: jsonEncode({
        'store_name': storeName,
        'scanned_products': scannedProducts,
        // user_id niet meer nodig
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Suggesties ophalen mislukt: ${response.statusCode}');
    }
  }
}
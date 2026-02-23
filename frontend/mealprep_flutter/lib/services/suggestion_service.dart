import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class SuggestionService {
  static const String _baseUrl = 'http://10.0.2.2:8000';

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
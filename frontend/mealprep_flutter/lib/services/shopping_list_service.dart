import 'package:http/http.dart' as http;
import 'dart:convert';

class ShoppingListService {
  static const String baseUrl = 'http://10.0.2.2:8081';

  static Future<void> createList({
    required String userId,
    required String listName,
  }) async {
    final uri = Uri.parse('$baseUrl/shopping-lists');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'list_name': listName,
      }),
    );

    if (response.statusCode != 201) {
      throw Exception('Kon lijst niet aanmaken (${response.statusCode})');
    }
  }
}

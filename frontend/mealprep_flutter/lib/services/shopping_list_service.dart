import 'dart:convert';
import 'package:http/http.dart' as http;

class ShoppingListService {
  static const String baseUrl = 'http://10.0.2.2:8081';

  static Future<List<Map<String, dynamic>>> getListItems(String listId) async {
    final uri = Uri.parse('$baseUrl/shopping-lists/$listId/items');
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Kon items niet ophalen (${response.statusCode})');
    }
  }

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
  static Future<void> addItemByBarcode({
  required String listId,
  required String barcode,
  int quantity = 1,
}) async {
  final uri = Uri.parse('$baseUrl/shopping-lists/$listId/items/by-barcode');
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'barcode': barcode,
      'quantity': quantity,
    }),
  );

  if (response.statusCode != 201) {
    throw Exception('Kon item niet toevoegen (${response.statusCode})');
  }
}
}

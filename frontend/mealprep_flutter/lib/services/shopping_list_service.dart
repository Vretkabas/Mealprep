import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingListService {
  static const String baseUrl = 'http://10.0.2.2:8081';


static Future<Map<String, String>> _authHeaders() async {
  final supabase = Supabase.instance.client;
  
  // Forceer token refresh als sessie bijna verlopen is
  Session? session = supabase.auth.currentSession;
  
  if (session == null) {
    throw Exception("Niet ingelogd - ga terug naar login");
  }

  // Ververs token als het verlopen is of bijna verloopt
  if (session.isExpired) {
    print("TOKEN VERLOPEN - probeer te verversen...");
    try {
      final refreshed = await supabase.auth.refreshSession();
      session = refreshed.session;
    } catch (e) {
      print("REFRESH MISLUKT: $e");
      throw Exception("Sessie verlopen, log opnieuw in");
    }
  }

  print("TOKEN GELDIG TOT: ${session!.expiresAt}");

  return {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${session.accessToken}',
  };
}

  static Future<List<Map<String, dynamic>>> getListItems(String listId) async {
    final uri = Uri.parse('$baseUrl/shopping-lists/$listId/items');
    final response = await http.get(uri, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((e) => e as Map<String, dynamic>).toList();
    } else {
      throw Exception('Kon items niet ophalen (${response.statusCode})');
    }
  }



static Future<void> createList({
  required String listName,
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/shopping-lists'),
    headers: await _authHeaders(),
    body: jsonEncode({
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
  final response = await http.post(
    Uri.parse('$baseUrl/shopping-lists/$listId/items/by-barcode'),
    headers: await _authHeaders(),
    body: jsonEncode({
      'barcode': barcode,
      'quantity': quantity,
    }),
  );

  if (response.statusCode != 201) {
    throw Exception('Kon item niet toevoegen (${response.statusCode})');
  }
}



static Future<List<Map<String, dynamic>>> getUserLists() async {
  final response = await http.get(
    Uri.parse('$baseUrl/shopping-lists'),
    headers: await _authHeaders(),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  } else {
    throw Exception('Kon lijsten niet ophalen (${response.statusCode})');
  }
}

static Future<void> updateItemChecked({
  required String itemId,
  required bool isChecked,
}) async {
  await http.patch(
    Uri.parse('$baseUrl/shopping-lists/items/$itemId'),
    headers: await _authHeaders(),
    body: jsonEncode({'is_checked': isChecked}),
  );
}

static Future<void> deleteItem({required String itemId}) async {
  await http.delete(
    Uri.parse('$baseUrl/shopping-lists/items/$itemId'),
    headers: await _authHeaders(),
  );
}


}

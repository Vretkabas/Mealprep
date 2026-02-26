import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    if (Platform.isIOS) {
      return 'http://localhost:8000';
    }

    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return 'http://localhost:8000';
    }

    // falback voor fysiek toestel
    return 'http://:8000'; // moet lokaal ip van pc ingeven
  }

  static Future<String> _getToken() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) throw Exception('Niet ingelogd');
    return session.accessToken;
  }

  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/favorites'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('Favorieten ophalen mislukt: ${response.statusCode}');
  }

  static Future<void> addFavorite(String productId) async {
    final token = await _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl/favorites'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'product_id': productId}),
    );
    if (response.statusCode != 200) {
      throw Exception('Toevoegen mislukt: ${response.statusCode}');
    }
  }

  static Future<void> removeFavorite(String productId) async {
    final token = await _getToken();
    final response = await http.delete(
      Uri.parse('$_baseUrl/favorites/$productId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception('Verwijderen mislukt: ${response.statusCode}');
    }
  }
}
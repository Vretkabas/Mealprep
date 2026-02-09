import 'package:http/http.dart' as http;
import 'dart:convert';

class FoodApiService {
  static const String baseUrl = 'http://localhost:8081';
  
  static Future<Map<String, dynamic>> fetchByBarcode(
    String barcode, {
    String? userId,
  }) async {
    try {
      // Bouw URL met optionele user_id parameter
      var uri = Uri.parse('$baseUrl/food/barcode/$barcode');
      
      if (userId != null) {
        uri = uri.replace(queryParameters: {'user_id': userId});
      }
      
      print('Fetching product from: $uri');
      
      final response = await http.get(uri);
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
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
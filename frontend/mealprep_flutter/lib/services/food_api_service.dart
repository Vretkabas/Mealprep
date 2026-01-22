import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodApiService {
  static Future<Map<String, dynamic>> fetchByBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse('http://localhost:8000/food/barcode/$barcode'),
    );

    if (response.statusCode != 200) {
      throw Exception('Product niet gevonden');
    }

    return jsonDecode(response.body);
  }
}

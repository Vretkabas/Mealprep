import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

String _getBaseUrl() {
  if (kIsWeb) {
    return 'http://localhost:8081';
  } else if (Platform.isAndroid) {
    return 'http://10.0.2.2:8081';
  } else {
    return 'http://localhost:8081';
  }
}

class FoodApiService {
  static Future<Map<String, dynamic>> fetchByBarcode(String barcode) async {
    final response = await http.get(
      Uri.parse('${_getBaseUrl()}/food/barcode/$barcode'),
    );

    if (response.statusCode != 200) {
      throw Exception('Product niet gevonden');
    }

    return jsonDecode(response.body);
  }
}



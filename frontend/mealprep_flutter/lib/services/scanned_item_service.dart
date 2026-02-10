import 'package:http/http.dart' as http;
import 'dart:convert';

class ScannedItemService {
  // backend url
  static const String baseUrl = 'http://localhost:8000'; 
  
  Future<void> logScan({
    required String barcode,
    required String scanMode,
    String? productId,
    Map<String, dynamic>? aiAnalysis,
    int? healthScore,
    String? userId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/scans/log'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'barcode': barcode,
          'scan_mode': scanMode,
          'product_id': productId,
          'ai_analysis': aiAnalysis,
          'health_score': healthScore,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        print('Scan logged successfully');
      } else {
        print('Failed to log scan: ${response.statusCode}');
        print('Response: ${response.body}');
        throw Exception('Failed to log scan');
      }
    } catch (e) {
      print('Error logging scan: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserScans({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/scans/user/$userId?limit=$limit'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['scans']);
      } else {
        throw Exception('Failed to fetch scans');
      }
    } catch (e) {
      print('Error fetching scans: $e');
      rethrow;
    }
  }
}
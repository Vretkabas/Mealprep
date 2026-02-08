import 'package:supabase_flutter/supabase_flutter.dart';

class ScannedItemService {
  final _client = Supabase.instance.client;

  // Test user ID for development/testing
  static const String testUserId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

  Future<void> logScan({
    required String barcode,
    required String scanMode,
    String? productId,
    Map<String, dynamic>? aiAnalysis,
    int? healthScore,
  }) async {
    try {
      // Try to get the current authenticated user
      final user = _client.auth.currentUser;
      final userId = user?.id ?? testUserId;

      if (user == null) {
        print('Warning: No authenticated user. Using test user ID: $testUserId');
      } else {
        print('Logging scan for user ${user.id}: $barcode');
      }

      await _client.from('scanned_items').insert({
        'user_id': userId,
        'product_id': productId,
        'barcode': barcode,
        'scan_mode': scanMode,
        'ai_analysis': aiAnalysis,
        'health_score': healthScore,
        'scanned_at': DateTime.now().toIso8601String(),
      });

      print('Scan logged successfully for user: $userId');
    } catch (e) {
      print('Error logging scan: $e');
      rethrow;
    }
  }
}

// services/user_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8081';
    return 'http://10.0.2.2:8081'; // Android emulator → nginx proxy
  }

  static Future<String?> _getToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  // 1. User settings ophalen (inclusief total_savings, doelen, etc.)
  static Future<Map<String, dynamic>?> getUserSettings() async {
    try {
      final token = await _getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/user/settings'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error fetching user settings: $e');
    }
    return null;
  }

  // 2. Profiel ophalen
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/user/profile/$userId'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching profile: $e");
    }
    return null;
  }

  // 2. Profiel updaten (De missende schakel!)
  static Future<bool> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/user/profile/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print("Update failed with status: ${response.statusCode}");
        print("Response body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error updating profile: $e");
      return false;
    }
  }

  // 3. Avatar uploaden (Multipart request)
  static Future<String?> uploadAvatar(String userId, File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/user/avatar/$userId'));
      
      // Voeg het bestand toe
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['avatar_url']; 
      }
    } catch (e) {
      print("Error uploading avatar: $e");
    }
    return null;
  }
}
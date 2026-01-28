import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class PosAuthApi {
  final _supabase = supabase.Supabase.instance.client;

  Future<Map<String, dynamic>> login(String deviceToken) async {
    // This used to be device-token based login. 
    // For now, we'll keep the signature but this might need restructuring 
    // if Supabase doesn't use device tokens directly.
    final url = Uri.parse('${AppConfig.apiBaseUrl}/pos/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'deviceToken': deviceToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('POS 로그인에 실패했습니다. (${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> loginAsOwner(String email, String password, {String? deviceId}) async {
    try {
      // 백엔드 API를 통해 로그인 (매장 및 POS 정보 포함)
      final url = Uri.parse('${AppConfig.apiBaseUrl}/pos/auth/login-owner');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'deviceId': deviceId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errorBody = response.body.isNotEmpty 
            ? jsonDecode(response.body) 
            : null;
        final errorMessage = errorBody?['message'] ?? 
            '이메일/비밀번호 로그인에 실패했습니다. (${response.statusCode})';
        throw Exception(errorMessage);
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('이메일/비밀번호 로그인에 실패했습니다: $e');
    }
  }

  Future<Map<String, dynamic>> selectPos({
    required String email,
    required String storeId,
    required String posId,
    String? deviceId,
  }) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/pos/auth/select-pos');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'storeId': storeId,
        'posId': posId,
        'deviceId': deviceId,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('POS 선택에 실패했습니다. (${response.statusCode})');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<bool> verifyToken(String token) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/pos/auth/verify');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }
}

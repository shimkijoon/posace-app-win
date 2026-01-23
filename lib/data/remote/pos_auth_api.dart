import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/app_config.dart';

class PosAuthApi {
  Future<Map<String, dynamic>> login(String deviceToken) async {
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

  Future<Map<String, dynamic>> loginAsOwner(String email, String password) async {
    final url = Uri.parse('${AppConfig.apiBaseUrl}/pos/auth/login-owner');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('이메일/비밀번호 로그인에 실패했습니다. (${response.statusCode})');
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

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
}

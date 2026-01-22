import 'dart:convert';
import 'package:http/http.dart' as http;
import './api_client.dart';

class PosSuspendedApi extends ApiClient {
  PosSuspendedApi({super.accessToken});

  Future<List<dynamic>> getSuspendedSales(String storeId) async {
    final response = await http.get(
      buildUri('/pos/stores/$storeId/suspended-sales'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('보류 주문을 불러오지 못했습니다: ${response.body}');
    }

    return jsonDecode(response.body) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSuspendedSale(String storeId, Map<String, dynamic> data) async {
    final response = await http.post(
      buildUri('/pos/stores/$storeId/suspended-sales'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode != 201) {
      throw Exception('보류 주문 저장 실패: ${response.body}');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<void> deleteSuspendedSale(String storeId, String id) async {
    final response = await http.delete(
      buildUri('/pos/stores/$storeId/suspended-sales/$id'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('보류 주문 삭제 실패: ${response.body}');
    }
  }
}

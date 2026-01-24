import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class TableManagementApi {
  TableManagementApi(this.apiClient);
  final ApiClient apiClient;

  Future<void> moveOrder({
    required String storeId,
    required String fromTableId,
    required String toTableId,
  }) async {
    final response = await http.post(
      apiClient.buildUri('/tables/move'),
      headers: apiClient.headers,
      body: jsonEncode({
        'storeId': storeId,
        'fromTableId': fromTableId,
        'toTableId': toTableId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to move order: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> mergeOrders({
    required String storeId,
    required String sourceTableId,
    required String targetTableId,
  }) async {
    final response = await http.post(
      apiClient.buildUri('/tables/merge'),
      headers: apiClient.headers,
      body: jsonEncode({
        'storeId': storeId,
        'sourceTableId': sourceTableId,
        'targetTableId': targetTableId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to merge orders: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> splitOrder({
    required String storeId,
    required String fromTableId,
    required String toTableId,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await http.post(
      apiClient.buildUri('/tables/split'),
      headers: apiClient.headers,
      body: jsonEncode({
        'storeId': storeId,
        'fromTableId': fromTableId,
        'toTableId': toTableId,
        'items': items,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to split order: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> groupPay({
    required String storeId,
    required List<String> tableIds,
    required String saleId,
  }) async {
    final response = await http.post(
      apiClient.buildUri('/tables/group-pay'),
      headers: apiClient.headers,
      body: jsonEncode({
        'storeId': storeId,
        'tableIds': tableIds,
        'saleId': saleId,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to process group payment: ${response.statusCode} ${response.body}');
    }
  }
  Future<Map<String, dynamic>> createOrUpdateOrder(Map<String, dynamic> payload) async {
    final response = await http.post(
      apiClient.buildUri('/tables/order'),
      headers: apiClient.headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to send table order: ${response.statusCode} ${response.body}');
    }
    return jsonDecode(response.body);
  }
}

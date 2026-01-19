import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class PosSalesApi {
  PosSalesApi(this.apiClient);

  final ApiClient apiClient;

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    final uri = apiClient.buildUri('/sales/pos');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
      body: json.encode(saleData),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to upload sale: ${response.statusCode} - ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }
}

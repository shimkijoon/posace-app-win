import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class PosSalesApi {
  PosSalesApi(this.apiClient);

  final ApiClient apiClient;

  Future<Map<String, dynamic>> createSale(Map<String, dynamic> saleData) async {
    final uri = apiClient.buildUri('/sales/pos');
    
    // Debug logging
    print('[PosSalesApi] ========== CREATE SALE REQUEST ==========');
    print('[PosSalesApi] API URL: $uri');
    print('[PosSalesApi] Has access token: ${apiClient.accessToken != null}');
    if (apiClient.accessToken != null) {
      print('[PosSalesApi] Token preview: ${apiClient.accessToken!.substring(0, 50)}...');
    }

    // The saleData is already built by the caller, so we just encode and send.
    // We can add a simple check or logging here if needed.
    final body = json.encode(saleData);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
      body: body,
    );
    
    print('[PosSalesApi] Response status: ${response.statusCode}');
    print('[PosSalesApi] Response body: ${response.body}');

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to upload sale: ${response.statusCode} - ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }
}

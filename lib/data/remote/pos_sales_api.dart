import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../common/services/error_diagnostic_service.dart';
import '../../common/exceptions/diagnostic_exception.dart';

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
    
    // Log the payload data
    print('[PosSalesApi] 📦 Payload keys: ${saleData.keys.toList()}');
    print('[PosSalesApi] 📦 Items count: ${(saleData['items'] as List?)?.length ?? 0}');
    if (saleData['items'] != null) {
      for (var i = 0; i < (saleData['items'] as List).length; i++) {
        final item = (saleData['items'] as List)[i];
        print('[PosSalesApi] 📦 Item $i: productId=${item['productId']}, qty=${item['qty']}, price=${item['price']}');
      }
    }
    print('[PosSalesApi] 📦 Payments count: ${(saleData['payments'] as List?)?.length ?? 0}');
    print('[PosSalesApi] 📦 Total amount: ${saleData['totalAmount']}');
    print('[PosSalesApi] 📦 Full payload: ${json.encode(saleData)}');

    // The saleData is already built by the caller, so we just encode and send.
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
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to upload sale: ${response.statusCode} - ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../common/services/error_diagnostic_service.dart';
import '../../common/exceptions/diagnostic_exception.dart';

class PosTableApi {
  PosTableApi(this.apiClient);

  final ApiClient apiClient;

  Future<List<Map<String, dynamic>>> getLayouts(String storeId) async {
    final uri = apiClient.buildUri('/tables/layouts', {'storeId': storeId});

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to fetch layouts: ${response.statusCode} - ${response.body}');
    }

    final data = json.decode(response.body) as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createOrUpdateOrder(Map<String, dynamic> orderData) async {
    final uri = apiClient.buildUri('/tables/order');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
      body: json.encode(orderData),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to update table order: ${response.statusCode} - ${response.body}');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<void> closeOrder(String orderId, String saleId) async {
    final uri = apiClient.buildUri('/tables/order/$orderId/close');

    final response = await http.patch(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
      body: json.encode({'saleId': saleId}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to close table order: ${response.statusCode} - ${response.body}');
    }
  }
}

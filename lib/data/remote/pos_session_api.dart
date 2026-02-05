import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../../common/services/error_diagnostic_service.dart';
import '../../common/exceptions/diagnostic_exception.dart';

class PosSessionApi {
  PosSessionApi(this.apiClient);

  final ApiClient apiClient;

  Future<Map<String, dynamic>> openSession(String storeId, int openingAmount) async {
    final uri = apiClient.buildUri('/pos/sessions/open');

    final response = await http.post(
      uri,
      headers: apiClient.headers,
      body: jsonEncode({
        'storeId': storeId,
        'openingAmount': openingAmount,
      }),
    );

    if (response.statusCode != 201) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to open session: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> closeSession(String sessionId, int closingAmount, int totalCash) async {
    final uri = apiClient.buildUri('/pos/sessions/close');

    final response = await http.post(
      uri,
      headers: apiClient.headers,
      body: jsonEncode({
        'sessionId': sessionId,
        'closingAmount': closingAmount, // Actual cash in drawer
        'totalCash': totalCash, // System calculated cash
      }),
    );

    if (response.statusCode != 201) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('Failed to close session: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body);
  }
}

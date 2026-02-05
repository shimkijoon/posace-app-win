import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../local/models/employee_model.dart';
import '../../common/services/error_diagnostic_service.dart';
import '../../common/exceptions/diagnostic_exception.dart';

class PosEmployeesApi {
  PosEmployeesApi(this.apiClient);

  final ApiClient apiClient;

  Future<List<EmployeeModel>> getEmployees(String storeId) async {
    final uri = apiClient.buildUri('/employees', {'storeId': storeId});

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
      throw Exception('Failed to fetch employees: ${response.statusCode} - ${response.body}');
    }

    final List<dynamic> data = json.decode(response.body);
    return data.map((e) => EmployeeModel.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<EmployeeModel> verifyPin(String storeId, String pin) async {
    final uri = apiClient.buildUri('/employees/verify-pin');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
      body: json.encode({
        'storeId': storeId,
        'pin': pin,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      // Try to parse as diagnostic error
      final diagnosticError = ErrorDiagnosticService.parseDiagnosticError(response);
      if (diagnosticError != null) {
        throw DiagnosticException(diagnosticError, response);
      }
      // Fallback to generic exception
      throw Exception('PIN verification failed: ${response.statusCode} - ${response.body}');
    }

    final Map<String, dynamic> data = json.decode(response.body);
    return EmployeeModel.fromMap(data);
  }
}

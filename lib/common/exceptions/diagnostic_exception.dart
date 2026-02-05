import '../../common/models/diagnostic_error_response.dart';
import 'package:http/http.dart' as http;

/// 진단 가능한 에러를 나타내는 예외 클래스
/// API 응답에서 DiagnosticErrorResponse를 파싱한 경우 이 예외를 throw합니다.
class DiagnosticException implements Exception {
  final DiagnosticErrorResponse error;
  final http.Response? response;

  DiagnosticException(this.error, [this.response]);

  @override
  String toString() => error.userMessage;
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:posace/common/models/diagnostic_error_response.dart';
import 'package:posace/common/enums/error_code.dart';

/// 에러 진단 및 리포트 생성 서비스
class ErrorDiagnosticService {
  /// HTTP 응답을 진단 가능한 에러로 파싱
  static DiagnosticErrorResponse? parseDiagnosticError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;

      // 서버가 DiagnosticErrorResponse 형식으로 응답한 경우
      if (json.containsKey('errorCode') &&
          json.containsKey('userMessage') &&
          json.containsKey('suggestedAction')) {
        return DiagnosticErrorResponse.fromJson(json);
      }

      // 구형 에러 응답 형식 - 변환 시도
      return _convertLegacyError(response.statusCode, json);
    } catch (e) {
      print('[ErrorDiagnostic] Failed to parse error: $e');
      return null;
    }
  }

  /// 구형 에러 응답을 DiagnosticErrorResponse로 변환
  static DiagnosticErrorResponse _convertLegacyError(
    int statusCode,
    Map<String, dynamic> json,
  ) {
    final message = json['message']?.toString() ?? 'Unknown error';

    ErrorCode errorCode;
    String userMessage;
    SuggestedAction suggestedAction;
    String actionMessage;

    // 상태 코드 기반 분류
    switch (statusCode) {
      case 401:
        errorCode = ErrorCode.authUnauthorized;
        userMessage = '인증이 필요합니다';
        suggestedAction = SuggestedAction.reLogin;
        actionMessage = '다시 로그인해주세요';
        break;

      case 404:
        errorCode = ErrorCode.resourceNotFound;
        userMessage = '요청하신 리소스를 찾을 수 없습니다';
        suggestedAction = SuggestedAction.syncMasterData;
        actionMessage = '마스터 데이터 동기화를 실행해주세요';
        break;

      case 409:
        errorCode = ErrorCode.dbConstraintViolation;
        userMessage = '데이터 제약 조건 위반';
        suggestedAction = SuggestedAction.syncMasterData;
        actionMessage = '마스터 데이터 동기화를 실행해주세요';
        break;

      case 500:
      case 502:
      case 503:
        errorCode = ErrorCode.serverInternalError;
        userMessage = '서버 오류가 발생했습니다';
        suggestedAction = SuggestedAction.contactSupport;
        actionMessage = '고객지원팀에 문의해주세요';
        break;

      default:
        errorCode = ErrorCode.unknownError;
        userMessage = '알 수 없는 오류가 발생했습니다';
        suggestedAction = SuggestedAction.retry;
        actionMessage = '다시 시도해주세요';
    }

    return DiagnosticErrorResponse(
      statusCode: statusCode,
      errorCode: errorCode,
      message: message,
      userMessage: userMessage,
      timestamp: DateTime.now(),
      path: '',
      suggestedAction: suggestedAction,
      actionMessage: actionMessage,
    );
  }

  /// 에러 리포트 생성 (AS 담당자용)
  static String generateErrorReport(
    DiagnosticErrorResponse error, {
    required Map<String, dynamic> systemInfo,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('POSAce 에러 리포트');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    // 1. 오류 요약
    buffer.writeln('【 오류 요약 】');
    buffer.writeln('시간: ${error.timestamp.toLocal()}');
    buffer.writeln('코드: ${error.errorCode.code}');
    buffer.writeln('상태: ${error.statusCode}');
    buffer.writeln('경로: ${error.path}');
    buffer.writeln();

    // 2. 사용자 메시지
    buffer.writeln('【 사용자 메시지 】');
    buffer.writeln(error.userMessage);
    buffer.writeln();

    // 3. 권장 조치
    buffer.writeln('【 권장 조치 】');
    buffer.writeln('액션: ${error.suggestedAction.action}');
    buffer.writeln('메시지: ${error.actionMessage}');
    buffer.writeln();

    // 4. 기술적 상세
    buffer.writeln('【 기술적 상세 】');
    buffer.writeln(error.message);
    buffer.writeln();

    // 5. 에러 상세 정보
    if (error.details != null) {
      buffer.writeln('【 상세 정보 】');
      final details = error.details!;

      if (details.entity != null) {
        buffer.writeln('엔티티: ${details.entity}');
      }

      if (details.missingIds != null && details.missingIds!.isNotEmpty) {
        buffer.writeln('누락된 ID:');
        for (final id in details.missingIds!) {
          buffer.writeln('  - $id');
        }
      }

      if (details.missingFields != null && details.missingFields!.isNotEmpty) {
        buffer.writeln('누락된 필드:');
        for (final field in details.missingFields!) {
          buffer.writeln('  - $field');
        }
      }

      if (details.constraint != null) {
        buffer.writeln('제약 조건: ${details.constraint}');
      }

      if (details.context != null) {
        buffer.writeln('컨텍스트: ${details.context}');
      }

      buffer.writeln();
    }

    // 6. 시스템 정보
    buffer.writeln('【 시스템 정보 】');
    systemInfo.forEach((key, value) {
      buffer.writeln('$key: $value');
    });
    buffer.writeln();

    // 7. 진단 정보
    if (error.diagnostic != null) {
      buffer.writeln('【 서버 진단 정보 】');
      final diag = error.diagnostic!;

      if (diag.serverVersion != null) {
        buffer.writeln('서버 버전: ${diag.serverVersion}');
      }

      if (diag.module != null) {
        buffer.writeln('모듈: ${diag.module}');
      }

      if (diag.stack != null) {
        buffer.writeln('스택 트레이스:');
        buffer.writeln(diag.stack);
      }

      buffer.writeln();
    }

    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return buffer.toString();
  }

  /// 간단한 에러 요약 생성 (UI 표시용)
  static String generateErrorSummary(DiagnosticErrorResponse error) {
    final buffer = StringBuffer();

    buffer.writeln('❌ ${error.userMessage}');
    buffer.writeln();
    buffer.writeln('원인: ${error.message}');
    buffer.writeln();
    buffer.writeln('해결: ${error.actionMessage}');

    if (error.details?.missingIds != null &&
        error.details!.missingIds!.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('누락된 항목: ${error.details!.missingIds!.length}개');
    }

    return buffer.toString();
  }
}

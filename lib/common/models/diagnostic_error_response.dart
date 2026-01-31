import '../../common/enums/error_code.dart';

/// 진단 가능한 에러 응답
class DiagnosticErrorResponse {
  final int statusCode;
  final ErrorCode errorCode;
  final String message;
  final String userMessage;
  final DateTime timestamp;
  final String path;
  final SuggestedAction suggestedAction;
  final String actionMessage;
  final ErrorDetails? details;
  final DiagnosticInfo? diagnostic;

  DiagnosticErrorResponse({
    required this.statusCode,
    required this.errorCode,
    required this.message,
    required this.userMessage,
    required this.timestamp,
    required this.path,
    required this.suggestedAction,
    required this.actionMessage,
    this.details,
    this.diagnostic,
  });

  factory DiagnosticErrorResponse.fromJson(Map<String, dynamic> json) {
    return DiagnosticErrorResponse(
      statusCode: json['statusCode'] as int,
      errorCode: ErrorCode.fromString(json['errorCode'] as String),
      message: json['message'] as String,
      userMessage: json['userMessage'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      path: json['path'] as String,
      suggestedAction:
          SuggestedAction.fromString(json['suggestedAction'] as String),
      actionMessage: json['actionMessage'] as String,
      details: json['details'] != null
          ? ErrorDetails.fromJson(json['details'] as Map<String, dynamic>)
          : null,
      diagnostic: json['diagnostic'] != null
          ? DiagnosticInfo.fromJson(json['diagnostic'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusCode': statusCode,
      'errorCode': errorCode.code,
      'message': message,
      'userMessage': userMessage,
      'timestamp': timestamp.toIso8601String(),
      'path': path,
      'suggestedAction': suggestedAction.action,
      'actionMessage': actionMessage,
      if (details != null) 'details': details!.toJson(),
      if (diagnostic != null) 'diagnostic': diagnostic!.toJson(),
    };
  }
}

/// 에러 상세 정보
class ErrorDetails {
  final List<String>? missingIds;
  final List<String>? missingFields;
  final Map<String, dynamic>? invalidValues;
  final String? constraint;
  final String? entity;
  final Map<String, dynamic>? context;

  ErrorDetails({
    this.missingIds,
    this.missingFields,
    this.invalidValues,
    this.constraint,
    this.entity,
    this.context,
  });

  factory ErrorDetails.fromJson(Map<String, dynamic> json) {
    return ErrorDetails(
      missingIds: json['missingIds'] != null
          ? List<String>.from(json['missingIds'])
          : null,
      missingFields: json['missingFields'] != null
          ? List<String>.from(json['missingFields'])
          : null,
      invalidValues: json['invalidValues'] as Map<String, dynamic>?,
      constraint: json['constraint'] as String?,
      entity: json['entity'] as String?,
      context: json['context'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (missingIds != null) 'missingIds': missingIds,
      if (missingFields != null) 'missingFields': missingFields,
      if (invalidValues != null) 'invalidValues': invalidValues,
      if (constraint != null) 'constraint': constraint,
      if (entity != null) 'entity': entity,
      if (context != null) 'context': context,
    };
  }
}

/// 진단 정보
class DiagnosticInfo {
  final String? serverVersion;
  final String? module;
  final String? stack;

  DiagnosticInfo({
    this.serverVersion,
    this.module,
    this.stack,
  });

  factory DiagnosticInfo.fromJson(Map<String, dynamic> json) {
    return DiagnosticInfo(
      serverVersion: json['serverVersion'] as String?,
      module: json['module'] as String?,
      stack: json['stack'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (serverVersion != null) 'serverVersion': serverVersion,
      if (module != null) 'module': module,
      if (stack != null) 'stack': stack,
    };
  }
}

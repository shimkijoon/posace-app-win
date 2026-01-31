import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/models/diagnostic_error_response.dart';
import '../../common/enums/error_code.dart';
import '../../common/services/error_diagnostic_service.dart';

/// 진단 가능한 에러를 표시하는 다이얼로그
class DiagnosticErrorDialog extends StatelessWidget {
  final DiagnosticErrorResponse error;
  final VoidCallback? onSyncPressed;
  final VoidCallback? onRetryPressed;
  final VoidCallback? onLoginPressed;
  final Map<String, dynamic>? systemInfo;

  const DiagnosticErrorDialog({
    Key? key,
    required this.error,
    this.onSyncPressed,
    this.onRetryPressed,
    this.onLoginPressed,
    this.systemInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 헤더
            Row(
              children: [
                Icon(
                  _getErrorIcon(),
                  color: _getErrorColor(),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getErrorTitle(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

            // 내용
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 사용자 메시지
                    _buildSection(
                      title: '오류 내용',
                      child: Text(
                        error.userMessage,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 원인
                    _buildSection(
                      title: '원인',
                      child: Text(
                        error.message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 해결 방법
                    _buildSection(
                      title: '해결 방법',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.blue.shade700,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                error.actionMessage,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 상세 정보 (접을 수 있게)
                    if (error.details != null) ...[
                      const SizedBox(height: 16),
                      ExpansionTile(
                        title: const Text(
                          '상세 정보',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        children: [
                          _buildDetailsContent(),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const Divider(height: 24),

            // 액션 버튼
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDetailsContent() {
    final details = error.details!;
    final items = <Widget>[];

    if (details.entity != null) {
      items.add(_buildDetailItem('엔티티', details.entity!));
    }

    if (details.missingIds != null && details.missingIds!.isNotEmpty) {
      items.add(_buildDetailItem(
        '누락된 항목',
        '${details.missingIds!.length}개',
      ));
      if (details.missingIds!.length <= 5) {
        for (final id in details.missingIds!) {
          items.add(Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              '• ${id.substring(0, 8)}...',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
          ));
        }
      }
    }

    if (details.constraint != null) {
      items.add(_buildDetailItem('제약 조건', details.constraint!));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items,
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final actions = <Widget>[];

    // 권장 조치에 따른 버튼
    switch (error.suggestedAction) {
      case SuggestedAction.syncMasterData:
        if (onSyncPressed != null) {
          actions.add(
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onSyncPressed!();
              },
              icon: const Icon(Icons.sync),
              label: const Text('지금 동기화하기'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          );
        }
        break;

      case SuggestedAction.retry:
        if (onRetryPressed != null) {
          actions.add(
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onRetryPressed!();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          );
        }
        break;

      case SuggestedAction.reLogin:
        if (onLoginPressed != null) {
          actions.add(
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onLoginPressed!();
              },
              icon: const Icon(Icons.login),
              label: const Text('다시 로그인'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          );
        }
        break;

      default:
        break;
    }

    // 리포트 복사 버튼 (항상 표시)
    if (systemInfo != null) {
      actions.add(
        OutlinedButton.icon(
          onPressed: () => _copyReport(context),
          icon: const Icon(Icons.copy, size: 18),
          label: const Text('리포트 복사'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
      );
    }

    // 닫기 버튼 (항상 표시)
    actions.add(
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('닫기'),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
        ),
      ),
    );

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: actions,
    );
  }

  void _copyReport(BuildContext context) {
    final report = ErrorDiagnosticService.generateErrorReport(
      error,
      systemInfo: systemInfo ?? {},
    );

    Clipboard.setData(ClipboardData(text: report));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('에러 리포트가 클립보드에 복사되었습니다'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  IconData _getErrorIcon() {
    switch (error.errorCode) {
      case ErrorCode.authUnauthorized:
      case ErrorCode.authTokenExpired:
      case ErrorCode.authTokenInvalid:
        return Icons.lock_outline;

      case ErrorCode.syncProductNotFound:
      case ErrorCode.syncCategoryNotFound:
      case ErrorCode.syncRequired:
        return Icons.sync_problem;

      case ErrorCode.saleProductNotFound:
      case ErrorCode.saleProductInactive:
        return Icons.inventory_2_outlined;

      case ErrorCode.serverInternalError:
      case ErrorCode.serverUnavailable:
        return Icons.cloud_off;

      default:
        return Icons.error_outline;
    }
  }

  Color _getErrorColor() {
    if (error.statusCode >= 500) {
      return Colors.red;
    } else if (error.statusCode >= 400) {
      return Colors.orange;
    } else {
      return Colors.blue;
    }
  }

  String _getErrorTitle() {
    if (error.statusCode >= 500) {
      return '서버 오류';
    } else if (error.statusCode == 401) {
      return '인증 필요';
    } else if (error.statusCode == 404) {
      return '데이터 없음';
    } else {
      return '오류 발생';
    }
  }

  /// 다이얼로그 표시 헬퍼 함수
  static Future<void> show({
    required BuildContext context,
    required DiagnosticErrorResponse error,
    VoidCallback? onSyncPressed,
    VoidCallback? onRetryPressed,
    VoidCallback? onLoginPressed,
    Map<String, dynamic>? systemInfo,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DiagnosticErrorDialog(
        error: error,
        onSyncPressed: onSyncPressed,
        onRetryPressed: onRetryPressed,
        onLoginPressed: onLoginPressed,
        systemInfo: systemInfo,
      ),
    );
  }
}

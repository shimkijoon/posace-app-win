import 'package:flutter/material.dart';
import '../../../core/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

class TitleBar extends StatelessWidget {
  const TitleBar({
    super.key,
    required this.title,
    required this.onHomePressed,
    this.leadingIcon = Icons.home,
    String? leadingTooltip,
  }) : _leadingTooltip = leadingTooltip;

  final String? _leadingTooltip;

  final String title;
  final VoidCallback onHomePressed;
  final IconData leadingIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 좌측: 홈/뒤로가기 버튼 + 타이틀
          Row(
            children: [
              IconButton(
                onPressed: onHomePressed,
                icon: Icon(leadingIcon, color: AppTheme.primary),
                tooltip: _leadingTooltip ?? AppLocalizations.of(context)!.translate('common.backToHome'),
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.primary.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          
          // 우측: 버전 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${AppConfig.appName} v1.0',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

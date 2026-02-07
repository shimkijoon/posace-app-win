import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

class FunctionButtons extends StatelessWidget {
  const FunctionButtons({
    super.key,
    required this.onDiscount,
    required this.onMember,
    required this.onCancel,
    required this.onHold,
    this.showHold = true,
  });

  final VoidCallback onDiscount;
  final VoidCallback onMember;
  final VoidCallback onCancel;
  final VoidCallback onHold;
  final bool showHold;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FunctionButton(
              label: AppLocalizations.of(context)!.discount,
              icon: Icons.local_offer_outlined,
              color: AppTheme.textSecondary,
              onTap: onDiscount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: AppLocalizations.of(context)!.member,
              icon: Icons.person_outline,
              color: AppTheme.textSecondary,
              onTap: onMember,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: AppLocalizations.of(context)!.cancelTransaction,
              icon: Icons.delete_outline,
              color: AppTheme.error,
              onTap: onCancel,
            ),
          ),
          if (showHold) ...[
            const SizedBox(width: 8),
            Expanded(
              child: _FunctionButton(
                label: AppLocalizations.of(context)!.holdTransaction,
                icon: Icons.pause_circle_outline,
                color: AppTheme.warning,
                onTap: onHold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FunctionButton extends StatelessWidget {
  const _FunctionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isPrimary ? color : AppTheme.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64, // 하단 오버플로우 방지
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center, // 가로 중앙 정렬 명시
            children: [
              Icon(icon, color: isPrimary ? Colors.white : color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center, // 텍스트 중앙 정렬
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11, // 폰트 크기 약간 줄여서 버튼에 맞게 조정
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
                maxLines: 2, // 최대 2줄로 제한
                overflow: TextOverflow.ellipsis, // 긴 텍스트 처리
              ),
            ],
          ),
        ),
      ),
    );
  }
}

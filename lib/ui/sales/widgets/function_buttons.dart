import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FunctionButtons extends StatelessWidget {
  const FunctionButtons({
    super.key,
    required this.onDiscount,
    required this.onMember,
    required this.onCancel,
    required this.onHold,
    this.onOrder,
  });

  final VoidCallback onDiscount;
  final VoidCallback onMember;
  final VoidCallback onCancel;
  final VoidCallback onHold;
  final VoidCallback? onOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              label: '할인',
              icon: Icons.local_offer_outlined,
              color: AppTheme.textSecondary,
              onTap: onDiscount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: '회원',
              icon: Icons.person_outline,
              color: AppTheme.textSecondary,
              onTap: onMember,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: '거래취소',
              icon: Icons.delete_outline,
              color: AppTheme.error,
              onTap: onCancel,
            ),
          ),
          const SizedBox(width: 8),
          if (onOrder != null)
            Expanded(
              child: _FunctionButton(
                label: '주문등록',
                icon: Icons.send,
                color: const Color(0xFF1B64DA), // Toast Blue
                onTap: onOrder!,
                isPrimary: true,
              ),
            )
          else
            Expanded(
              child: _FunctionButton(
                label: '거래보류',
                icon: Icons.pause_circle_outline,
                color: AppTheme.warning,
                onTap: onHold,
              ),
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isPrimary ? Colors.white : color, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPrimary ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

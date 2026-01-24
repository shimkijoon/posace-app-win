import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FunctionButtons extends StatelessWidget {
  const FunctionButtons({
    super.key,
    required this.onDiscount,
    required this.onMember,
    required this.onCancel,
    required this.onHold,
    required this.onCheckout,
    this.onOrder,
    required this.isCheckoutEnabled,
  });

  final VoidCallback onDiscount;
  final VoidCallback onMember;
  final VoidCallback onCancel;
  final VoidCallback onHold;
  final VoidCallback onCheckout;
  final VoidCallback? onOrder;
  final bool isCheckoutEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          top: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _FunctionButton(
              label: '할인',
              icon: Icons.discount,
              color: AppTheme.secondary,
              onTap: onDiscount,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: '회원',
              icon: Icons.person,
              color: AppTheme.primary,
              onTap: onMember,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: '취소',
              icon: Icons.cancel_outlined,
              color: AppTheme.error,
              onTap: onCancel,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _FunctionButton(
              label: onOrder != null ? '주문완료' : '거래보류',
              icon: onOrder != null ? Icons.check_circle_outline : Icons.pause_circle_outline,
              color: AppTheme.warning,
              onTap: onOrder ?? onHold,
            ),
          ),
          const SizedBox(width: 8),
          // 결제 버튼 (다른 버튼과 같은 크기)
          Expanded(
            flex: 2, // 결제 버튼은 약간 더 크게
            child: _CheckoutButton(
              onTap: onCheckout,
              enabled: isCheckoutEnabled,
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
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({
    required this.onTap,
    required this.enabled,
  });

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? AppTheme.success : AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? AppTheme.success : AppTheme.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: enabled
                    ? AppTheme.success.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: enabled ? 6 : 4,
                offset: Offset(0, enabled ? 3 : 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.payment,
                color: enabled ? Colors.white : AppTheme.textSecondary,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                '결제',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: enabled ? Colors.white : AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

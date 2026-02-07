import 'package:flutter/material.dart';
import '../../../data/models/unified_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

class OrderFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final OrderType? selectedType;
  final Function(String?) onStatusChanged;
  final Function(OrderType?) onTypeChanged;
  final VoidCallback onClearFilters;

  const OrderFilterBar({
    Key? key,
    this.selectedStatus,
    this.selectedType,
    required this.onStatusChanged,
    required this.onTypeChanged,
    required this.onClearFilters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasFilters = selectedStatus != null || selectedType != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.translate('orders.filter.title'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (hasFilters)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: Text(AppLocalizations.of(context)!.translate('orders.filter.reset')),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 필터 칩들
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 주문 타입 필터
              _buildTypeFilterChips(context),
              
              // 구분선
              Container(
                width: 1,
                height: 32,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              
              // 상태 필터
              _buildStatusFilterChips(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.typeAll'),
          isSelected: selectedType == null,
          onTap: () => onTypeChanged(null),
          icon: Icons.all_inclusive,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.typeTable'),
          isSelected: selectedType == OrderType.TABLE,
          onTap: () => onTypeChanged(OrderType.TABLE),
          icon: Icons.table_restaurant,
          color: Colors.blue,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.typeTakeout'),
          isSelected: selectedType == OrderType.TAKEOUT,
          onTap: () => onTypeChanged(OrderType.TAKEOUT),
          icon: Icons.takeout_dining,
          color: Colors.green,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.typeDelivery'),
          isSelected: selectedType == OrderType.DELIVERY,
          onTap: () => onTypeChanged(OrderType.DELIVERY),
          icon: Icons.delivery_dining,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatusFilterChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusAll'),
          isSelected: selectedStatus == null,
          onTap: () => onStatusChanged(null),
          icon: Icons.all_inclusive,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusPending'),
          isSelected: selectedStatus == 'PENDING',
          onTap: () => onStatusChanged('PENDING'),
          icon: Icons.hourglass_empty,
          color: Colors.grey,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusConfirmed'),
          isSelected: selectedStatus == 'CONFIRMED',
          onTap: () => onStatusChanged('CONFIRMED'),
          icon: Icons.check_circle_outline,
          color: Colors.blue,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusCooking'),
          isSelected: selectedStatus == 'COOKING',
          onTap: () => onStatusChanged('COOKING'),
          icon: Icons.restaurant,
          color: Colors.orange,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusReady'),
          isSelected: selectedStatus == 'READY',
          onTap: () => onStatusChanged('READY'),
          icon: Icons.done,
          color: Colors.green,
        ),
        _buildFilterChip(
          label: AppLocalizations.of(context)!.translate('orders.filter.statusCompleted'),
          isSelected: selectedStatus == 'SERVED' || selectedStatus == 'PICKED_UP',
          onTap: () => onStatusChanged('SERVED'),
          icon: Icons.done_all,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    IconData? icon,
    Color? color,
  }) {
    final chipColor = color ?? AppTheme.primary;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : chipColor,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : chipColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
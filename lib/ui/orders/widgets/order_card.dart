import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/unified_order.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';

class OrderCard extends StatelessWidget {
  final UnifiedOrder order;
  final Function(String orderId, UnifiedOrderStatus status)? onStatusUpdate;
  final Function(String orderId, CookingStatus status)? onCookingStatusUpdate;
  final VoidCallback? onTableManage;
  final VoidCallback? onTap;

  const OrderCard({
    Key? key,
    required this.order,
    this.onStatusUpdate,
    this.onCookingStatusUpdate,
    this.onTableManage,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                children: [
                  // 주문 타입 아이콘
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeColor(order.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(order.type),
                      color: _getTypeColor(order.type),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 주문번호 및 시간
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.orderNumber,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DateFormat('MM/dd HH:mm').format(order.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 상태/결제 배지
                  _buildStatusBadge(context),
                  const SizedBox(width: 6),
                  _buildPaymentBadge(context),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 고객 정보 (테이크아웃) 또는 테이블 정보
              if (order.isTakeoutOrder && order.customerName != null) ...[
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      order.customerName!,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (order.customerPhone != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        order.customerPhone!,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              if (order.isTableOrder && order.table != null) ...[
                Row(
                  children: [
                    Icon(Icons.table_restaurant, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      l10n.translate('orders.card.tableLabel').replaceAll('{tableNumber}', '${order.table!['tableNumber']}'),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (order.guestCount != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        l10n.translate('orders.card.guestCount').replaceAll('{count}', '${order.guestCount}'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // 예약 시간 (테이크아웃)
              if (order.scheduledTime != null) ...[
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.orange[600]),
                    const SizedBox(width: 4),
                    Text(
                      l10n
                          .translate('orders.card.pickupSchedule')
                          .replaceAll('{time}', DateFormat('HH:mm').format(order.scheduledTime!)),
                      style: TextStyle(
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // 주문 아이템 요약
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n
                              .translate('orders.card.itemsSummary')
                              .replaceAll('{count}', '${order.items.length}'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₩${NumberFormat('#,###').format(order.totalAmount)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ...order.items.take(2).map((item) => Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${item.productName} x${item.qty}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    )),
                    if (order.items.length > 2)
                      Text(
                        l10n
                            .translate('orders.card.itemsMore')
                            .replaceAll('{count}', '${order.items.length - 2}'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              
              // 조리 상태 및 시간 정보
              if (order.cookingStatus != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _getCookingStatusIcon(order.cookingStatus!),
                      size: 16,
                      color: _getCookingStatusColor(order.cookingStatus!),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      order.cookingStatusDisplayText,
                      style: TextStyle(
                        color: _getCookingStatusColor(order.cookingStatus!),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (order.estimatedCompletionTime != null)
                      Text(
                        l10n
                            .translate('orders.card.eta')
                            .replaceAll('{time}', DateFormat('HH:mm').format(order.estimatedCompletionTime!)),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
              
              // 메모
              if (order.note != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          order.note!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.amber[800],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // 액션 버튼들
              const SizedBox(height: 12),
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final color = _getStatusColor(order.status);
    final label = _statusLabel(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _statusLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (order.status) {
      case UnifiedOrderStatus.PENDING:
        return l10n.translate('orders.status.pending');
      case UnifiedOrderStatus.CONFIRMED:
        return l10n.translate('orders.status.confirmed');
      case UnifiedOrderStatus.COOKING:
        return l10n.translate('orders.status.cooking');
      case UnifiedOrderStatus.READY:
        return order.isTakeoutOrder
            ? l10n.translate('orders.status.pickupReady')
            : l10n.translate('orders.status.serveReady');
      case UnifiedOrderStatus.SERVED:
        return l10n.translate('orders.status.served');
      case UnifiedOrderStatus.PICKED_UP:
        return l10n.translate('orders.status.pickedUp');
      case UnifiedOrderStatus.CANCELLED:
        return l10n.translate('orders.status.cancelled');
      case UnifiedOrderStatus.MODIFIED:
        return l10n.translate('orders.status.modified');
    }
  }

  Widget _buildPaymentBadge(BuildContext context) {
    final isPaid = order.isPaid;
    final color = isPaid ? Colors.green : Colors.red;
    final label = isPaid
        ? AppLocalizations.of(context)!.translate('orders.paymentBadge.paid')
        : AppLocalizations.of(context)!.translate('orders.paymentBadge.unpaid');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    final buttons = <Widget>[];

    // 주문 상태 전환 버튼
    if (order.status == UnifiedOrderStatus.PENDING && onStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onStatusUpdate!(order.id, UnifiedOrderStatus.CONFIRMED),
          icon: const Icon(Icons.check_circle, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.confirmOrder')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    if (order.status == UnifiedOrderStatus.CONFIRMED &&
        order.cookingStatus == null &&
        onStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onStatusUpdate!(order.id, UnifiedOrderStatus.COOKING),
          icon: const Icon(Icons.play_arrow, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.startCooking')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    if (order.status == UnifiedOrderStatus.COOKING &&
        order.cookingStatus == null &&
        onStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onStatusUpdate!(order.id, UnifiedOrderStatus.READY),
          icon: const Icon(Icons.done, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.readyComplete')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // 테이블 전환 (테이블 주문만)
    if (order.isTableOrder && onTableManage != null) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: onTableManage,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.switchTable')),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // 조리 관련 버튼
    if (order.cookingStatus == CookingStatus.WAITING && onCookingStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onCookingStatusUpdate!(order.id, CookingStatus.IN_PROGRESS),
          icon: const Icon(Icons.play_arrow, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.cookingStart')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    if (order.cookingStatus == CookingStatus.IN_PROGRESS && onCookingStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onCookingStatusUpdate!(order.id, CookingStatus.COMPLETED),
          icon: const Icon(Icons.check, size: 16),
          label: Text(AppLocalizations.of(context)!.translate('orders.action.cookingComplete')),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // 서빙/픽업 완료 버튼
    if (order.status == UnifiedOrderStatus.READY && onStatusUpdate != null) {
      final completeStatus = order.isTableOrder 
          ? UnifiedOrderStatus.SERVED 
          : UnifiedOrderStatus.PICKED_UP;
      final buttonText = order.isTableOrder
          ? AppLocalizations.of(context)!.translate('orders.action.serveComplete')
          : AppLocalizations.of(context)!.translate('orders.action.pickupComplete');
      
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onStatusUpdate!(order.id, completeStatus),
          icon: const Icon(Icons.done_all, size: 16),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Color _getTypeColor(OrderType type) {
    switch (type) {
      case OrderType.TABLE:
        return Colors.blue;
      case OrderType.TAKEOUT:
        return Colors.green;
      case OrderType.DELIVERY:
        return Colors.purple;
    }
  }

  IconData _getTypeIcon(OrderType type) {
    switch (type) {
      case OrderType.TABLE:
        return Icons.table_restaurant;
      case OrderType.TAKEOUT:
        return Icons.takeout_dining;
      case OrderType.DELIVERY:
        return Icons.delivery_dining;
    }
  }

  Color _getStatusColor(UnifiedOrderStatus status) {
    switch (status) {
      case UnifiedOrderStatus.PENDING:
        return Colors.grey;
      case UnifiedOrderStatus.CONFIRMED:
        return Colors.blue;
      case UnifiedOrderStatus.COOKING:
        return Colors.orange;
      case UnifiedOrderStatus.READY:
        return Colors.green;
      case UnifiedOrderStatus.SERVED:
      case UnifiedOrderStatus.PICKED_UP:
        return Colors.teal;
      case UnifiedOrderStatus.CANCELLED:
        return Colors.red;
      case UnifiedOrderStatus.MODIFIED:
        return Colors.amber;
    }
  }

  Color _getCookingStatusColor(CookingStatus status) {
    switch (status) {
      case CookingStatus.WAITING:
        return Colors.grey;
      case CookingStatus.IN_PROGRESS:
        return Colors.orange;
      case CookingStatus.COMPLETED:
        return Colors.green;
    }
  }

  IconData _getCookingStatusIcon(CookingStatus status) {
    switch (status) {
      case CookingStatus.WAITING:
        return Icons.hourglass_empty;
      case CookingStatus.IN_PROGRESS:
        return Icons.restaurant;
      case CookingStatus.COMPLETED:
        return Icons.check_circle;
    }
  }
}
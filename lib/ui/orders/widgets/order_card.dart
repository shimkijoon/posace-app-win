import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/unified_order.dart';
import '../../../core/theme/app_theme.dart';

class OrderCard extends StatelessWidget {
  final UnifiedOrder order;
  final Function(String orderId, UnifiedOrderStatus status)? onStatusUpdate;
  final Function(String orderId, CookingStatus status)? onCookingStatusUpdate;
  final VoidCallback? onTap;

  const OrderCard({
    Key? key,
    required this.order,
    this.onStatusUpdate,
    this.onCookingStatusUpdate,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  
                  // 상태 배지
                  _buildStatusBadge(),
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
                      '테이블 ${order.table!['tableNumber']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (order.guestCount != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.people, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text('${order.guestCount}명'),
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
                      '픽업 예정: ${DateFormat('HH:mm').format(order.scheduledTime!)}',
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
                          '주문 내역 (${order.items.length}개)',
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
                        '외 ${order.items.length - 2}개',
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
                        '예상 완료: ${DateFormat('HH:mm').format(order.estimatedCompletionTime!)}',
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
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    final color = _getStatusColor(order.status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        order.statusDisplayText,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final buttons = <Widget>[];

    // 조리 관련 버튼
    if (order.cookingStatus == CookingStatus.WAITING && onCookingStatusUpdate != null) {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => onCookingStatusUpdate!(order.id, CookingStatus.IN_PROGRESS),
          icon: const Icon(Icons.play_arrow, size: 16),
          label: const Text('조리 시작'),
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
          label: const Text('조리 완료'),
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
      final buttonText = order.isTableOrder ? '서빙 완료' : '픽업 완료';
      
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
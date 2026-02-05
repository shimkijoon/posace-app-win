import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/models/unified_order.dart';
import '../../../core/theme/app_theme.dart';
import 'order_card.dart';

class CookingQueueSection extends StatelessWidget {
  final List<UnifiedOrder> orders;
  final bool isLoading;
  final Function(String orderId) onStartCooking;
  final Function(String orderId) onCompleteCooking;
  final VoidCallback onRefresh;

  const CookingQueueSection({
    Key? key,
    required this.orders,
    required this.isLoading,
    required this.onStartCooking,
    required this.onCompleteCooking,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // 조리 대기열 요약
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary.withOpacity(0.1), AppTheme.primary.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.restaurant,
                size: 32,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '조리 대기열',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${orders.length}개 주문 대기 중',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              _buildQueueStats(),
            ],
          ),
        ),

        // 주문 목록
        Expanded(
          child: orders.isEmpty ? _buildEmptyState() : _buildOrderList(),
        ),
      ],
    );
  }

  Widget _buildQueueStats() {
    final waitingCount = orders.where((o) => o.cookingStatus == CookingStatus.WAITING).length;
    final cookingCount = orders.where((o) => o.cookingStatus == CookingStatus.IN_PROGRESS).length;
    final readyCount = orders.where((o) => o.cookingStatus == CookingStatus.COMPLETED).length;

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatChip('대기', waitingCount, Colors.grey),
            const SizedBox(width: 8),
            _buildStatChip('조리중', cookingCount, Colors.orange),
            const SizedBox(width: 8),
            _buildStatChip('완료', readyCount, Colors.green),
          ],
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '조리 대기 중인 주문이 없습니다',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '새로운 주문이 들어오면 여기에 표시됩니다',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList() {
    // 우선순위별로 그룹화
    final priorityGroups = <int, List<UnifiedOrder>>{};
    for (final order in orders) {
      priorityGroups.putIfAbsent(order.priority, () => []).add(order);
    }

    final sortedPriorities = priorityGroups.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _getTotalItemCount(sortedPriorities, priorityGroups),
        itemBuilder: (context, index) {
          return _buildListItem(index, sortedPriorities, priorityGroups);
        },
      ),
    );
  }

  int _getTotalItemCount(List<int> priorities, Map<int, List<UnifiedOrder>> groups) {
    int count = 0;
    for (final priority in priorities) {
      if (priority > 0) count++; // 우선순위 헤더
      count += groups[priority]!.length; // 주문들
    }
    return count;
  }

  Widget _buildListItem(int index, List<int> priorities, Map<int, List<UnifiedOrder>> groups) {
    int currentIndex = 0;
    
    for (final priority in priorities) {
      // 우선순위 헤더 (priority > 0일 때만)
      if (priority > 0) {
        if (currentIndex == index) {
          return _buildPriorityHeader(priority);
        }
        currentIndex++;
      }
      
      // 해당 우선순위의 주문들
      final ordersInPriority = groups[priority]!;
      for (int i = 0; i < ordersInPriority.length; i++) {
        if (currentIndex == index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildQueueOrderCard(ordersInPriority[i], i + 1),
          );
        }
        currentIndex++;
      }
    }
    
    return const SizedBox.shrink();
  }

  Widget _buildPriorityHeader(int priority) {
    String priorityText;
    Color priorityColor;
    
    switch (priority) {
      case 1:
        priorityText = '단골 고객';
        priorityColor = Colors.blue;
        break;
      case 2:
        priorityText = '대량 주문';
        priorityColor = Colors.purple;
        break;
      case 3:
        priorityText = 'VIP 고객';
        priorityColor = Colors.amber;
        break;
      case 4:
        priorityText = '긴급 주문';
        priorityColor = Colors.red;
        break;
      default:
        priorityText = '우선순위 $priority';
        priorityColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: priorityColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.priority_high, color: priorityColor, size: 20),
          const SizedBox(width: 8),
          Text(
            priorityText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: priorityColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueOrderCard(UnifiedOrder order, int queuePosition) {
    return Stack(
      children: [
        OrderCard(
          order: order,
          onCookingStatusUpdate: (orderId, status) {
            if (status == CookingStatus.IN_PROGRESS) {
              onStartCooking(orderId);
            } else if (status == CookingStatus.COMPLETED) {
              onCompleteCooking(orderId);
            }
          },
        ),
        
        // 대기 순서 배지
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#$queuePosition',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        // 예상 시간 배지 (조리 중일 때)
        if (order.cookingStatus == CookingStatus.IN_PROGRESS && order.estimatedCompletionTime != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '완료 예정: ${DateFormat('HH:mm').format(order.estimatedCompletionTime!)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
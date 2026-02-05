import 'dart:async';
import '../../data/models/unified_order.dart';

/// 주문 데이터 캐시 서비스
/// 실시간 업데이트 시 서버 트래픽을 절약하기 위한 캐시 메커니즘
class OrderCacheService {
  static final OrderCacheService _instance = OrderCacheService._internal();
  factory OrderCacheService() => _instance;
  OrderCacheService._internal();

  // 캐시된 주문 데이터
  final Map<String, UnifiedOrder> _orderCache = {};
  
  // 캐시된 주문 목록 (필터별)
  final Map<String, List<UnifiedOrder>> _orderListCache = {};
  
  // 캐시 만료 시간 (기본 30초)
  final Map<String, DateTime> _cacheExpiry = {};
  
  // 캐시 유효 기간 (초)
  static const int _cacheValiditySeconds = 30;
  
  // 실시간 업데이트 스트림
  final StreamController<List<UnifiedOrder>> _ordersStreamController = 
      StreamController<List<UnifiedOrder>>.broadcast();
  
  Stream<List<UnifiedOrder>> get ordersStream => _ordersStreamController.stream;

  /// 주문 캐시 저장
  void cacheOrder(UnifiedOrder order) {
    _orderCache[order.id] = order;
    _cacheExpiry[order.id] = DateTime.now().add(
      const Duration(seconds: _cacheValiditySeconds),
    );
  }

  /// 주문 목록 캐시 저장
  void cacheOrderList(String key, List<UnifiedOrder> orders) {
    _orderListCache[key] = List.from(orders);
    _cacheExpiry[key] = DateTime.now().add(
      const Duration(seconds: _cacheValiditySeconds),
    );
    
    // 개별 주문도 캐시에 저장
    for (final order in orders) {
      cacheOrder(order);
    }
    
    // 실시간 업데이트 스트림에 전송
    _ordersStreamController.add(orders);
  }

  /// 캐시된 주문 조회
  UnifiedOrder? getCachedOrder(String orderId) {
    if (!_isCacheValid(orderId)) {
      _orderCache.remove(orderId);
      _cacheExpiry.remove(orderId);
      return null;
    }
    return _orderCache[orderId];
  }

  /// 캐시된 주문 목록 조회
  List<UnifiedOrder>? getCachedOrderList(String key) {
    if (!_isCacheValid(key)) {
      _orderListCache.remove(key);
      _cacheExpiry.remove(key);
      return null;
    }
    return _orderListCache[key];
  }

  /// 캐시 유효성 검사
  bool _isCacheValid(String key) {
    final expiry = _cacheExpiry[key];
    if (expiry == null) return false;
    return DateTime.now().isBefore(expiry);
  }

  /// 특정 주문 상태 업데이트 (캐시 및 스트림)
  void updateOrderStatus(String orderId, UnifiedOrderStatus status) {
    final cachedOrder = _orderCache[orderId];
    if (cachedOrder != null) {
      final updatedOrder = cachedOrder.copyWith(
        status: status,
        updatedAt: DateTime.now(),
      );
      cacheOrder(updatedOrder);
      
      // 모든 캐시된 목록에서 해당 주문 업데이트
      _updateOrderInLists(updatedOrder);
    }
  }

  /// 특정 주문 조리 상태 업데이트
  void updateOrderCookingStatus(String orderId, CookingStatus cookingStatus) {
    final cachedOrder = _orderCache[orderId];
    if (cachedOrder != null) {
      final updatedOrder = cachedOrder.copyWith(
        cookingStatus: cookingStatus,
        cookingStartedAt: cookingStatus == CookingStatus.IN_PROGRESS 
            ? DateTime.now() 
            : cachedOrder.cookingStartedAt,
        cookingCompletedAt: cookingStatus == CookingStatus.COMPLETED 
            ? DateTime.now() 
            : cachedOrder.cookingCompletedAt,
        updatedAt: DateTime.now(),
      );
      cacheOrder(updatedOrder);
      
      // 모든 캐시된 목록에서 해당 주문 업데이트
      _updateOrderInLists(updatedOrder);
    }
  }

  /// 캐시된 목록들에서 주문 업데이트
  void _updateOrderInLists(UnifiedOrder updatedOrder) {
    for (final key in _orderListCache.keys) {
      final list = _orderListCache[key];
      if (list != null) {
        final index = list.indexWhere((order) => order.id == updatedOrder.id);
        if (index != -1) {
          list[index] = updatedOrder;
          // 실시간 업데이트 스트림에 전송
          _ordersStreamController.add(List.from(list));
        }
      }
    }
  }

  /// 주문 제거 (픽업 완료 등)
  void removeOrder(String orderId) {
    _orderCache.remove(orderId);
    _cacheExpiry.remove(orderId);
    
    // 모든 캐시된 목록에서 주문 제거
    for (final key in _orderListCache.keys) {
      final list = _orderListCache[key];
      if (list != null) {
        list.removeWhere((order) => order.id == orderId);
        // 실시간 업데이트 스트림에 전송
        _ordersStreamController.add(List.from(list));
      }
    }
  }

  /// 캐시 키 생성 (필터 조건 기반)
  String generateCacheKey({
    String? storeId,
    OrderType? type,
    UnifiedOrderStatus? status,
    CookingStatus? cookingStatus,
  }) {
    final keyParts = <String>[];
    if (storeId != null) keyParts.add('store:$storeId');
    if (type != null) keyParts.add('type:${type.name}');
    if (status != null) keyParts.add('status:${status.name}');
    if (cookingStatus != null) keyParts.add('cooking:${cookingStatus.name}');
    
    return keyParts.join('|');
  }

  /// 전체 캐시 초기화
  void clearCache() {
    _orderCache.clear();
    _orderListCache.clear();
    _cacheExpiry.clear();
  }

  /// 만료된 캐시 정리
  void cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cacheExpiry.entries) {
      if (now.isAfter(entry.value)) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _orderCache.remove(key);
      _orderListCache.remove(key);
      _cacheExpiry.remove(key);
    }
  }

  /// 캐시 통계 정보
  Map<String, dynamic> getCacheStats() {
    return {
      'orderCacheSize': _orderCache.length,
      'listCacheSize': _orderListCache.length,
      'totalCacheEntries': _cacheExpiry.length,
      'validEntries': _cacheExpiry.entries
          .where((entry) => DateTime.now().isBefore(entry.value))
          .length,
    };
  }

  /// 리소스 정리
  void dispose() {
    _ordersStreamController.close();
  }
}
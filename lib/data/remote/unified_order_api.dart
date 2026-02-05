import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/unified_order.dart';
import 'api_client.dart';
import '../../core/cache/order_cache_service.dart';

class UnifiedOrderApi {
  final ApiClient _apiClient;
  final OrderCacheService _cacheService = OrderCacheService();

  UnifiedOrderApi(this._apiClient);

  /// 주문 생성
  Future<UnifiedOrder> createOrder({
    required String storeId,
    required OrderType type,
    required double totalAmount,
    required List<CreateOrderItemRequest> items,
    String? sessionId,
    String? employeeId,
    String? note,
    int priority = 0,
    int estimatedMinutes = 15,
    // 테이블 주문 특화
    String? tableId,
    int? guestCount,
    // 테이크아웃 특화
    String? customerName,
    String? customerPhone,
    DateTime? scheduledTime,
  }) async {
    final body = {
      'storeId': storeId,
      'type': type.name,
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toJson()).toList(),
      if (sessionId != null) 'sessionId': sessionId,
      if (employeeId != null) 'employeeId': employeeId,
      if (note != null) 'note': note,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      if (tableId != null) 'tableId': tableId,
      if (guestCount != null) 'guestCount': guestCount,
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (scheduledTime != null) 'scheduledTime': scheduledTime.toIso8601String(),
    };

    final uri = _apiClient.buildUri('/orders');
    final response = await http.post(
      uri,
      headers: _apiClient.headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return UnifiedOrder.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create order: ${response.statusCode} ${response.body}');
    }
  }

  /// 주문 목록 조회 (캐시 기능 포함)
  Future<List<UnifiedOrder>> getOrders({
    required String storeId,
    OrderType? type,
    String? status,
    String? cookingStatus,
    String? tableId,
    int limit = 100,
    int offset = 0,
    bool useCache = true,
  }) async {
    // 캐시 키 생성
    final cacheKey = _cacheService.generateCacheKey(
      storeId: storeId,
      type: type,
    );

    // 캐시에서 먼저 확인
    if (useCache) {
      final cachedOrders = _cacheService.getCachedOrderList(cacheKey);
      if (cachedOrders != null) {
        return cachedOrders;
      }
    }

    final queryParams = <String, String>{
      'storeId': storeId,
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (type != null) queryParams['type'] = type.name;
    if (status != null) queryParams['status'] = status;
    if (cookingStatus != null) queryParams['cookingStatus'] = cookingStatus;
    if (tableId != null) queryParams['tableId'] = tableId;

    final uri = _apiClient.buildUri('/orders', queryParams);
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      final orders = jsonList.map((json) => UnifiedOrder.fromJson(json)).toList();
      
      // 캐시에 저장
      _cacheService.cacheOrderList(cacheKey, orders);
      
      return orders;
    } else {
      throw Exception('Failed to get orders: ${response.statusCode} ${response.body}');
    }
  }

  /// 조리 대기열 조회 (캐시 기능 포함)
  Future<List<UnifiedOrder>> getCookingQueue(String storeId, {bool useCache = true}) async {
    final cacheKey = 'cooking-queue:$storeId';

    // 캐시에서 먼저 확인
    if (useCache) {
      final cachedOrders = _cacheService.getCachedOrderList(cacheKey);
      if (cachedOrders != null) {
        return cachedOrders;
      }
    }

    final uri = _apiClient.buildUri('/orders/cooking-queue', {'storeId': storeId});
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      final orders = jsonList.map((json) => UnifiedOrder.fromJson(json)).toList();
      
      // 캐시에 저장
      _cacheService.cacheOrderList(cacheKey, orders);
      
      return orders;
    } else {
      throw Exception('Failed to get cooking queue: ${response.statusCode} ${response.body}');
    }
  }

  /// 테이크아웃 주문 조회
  Future<List<UnifiedOrder>> getTakeoutOrders(String storeId, {String? status}) async {
    final queryParams = <String, String>{'storeId': storeId};
    if (status != null) queryParams['status'] = status;

    final uri = _apiClient.buildUri('/orders/takeout', queryParams);
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => UnifiedOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get takeout orders: ${response.statusCode} ${response.body}');
    }
  }

  /// 테이블 주문 조회
  Future<List<UnifiedOrder>> getTableOrders(String storeId, {String? tableId}) async {
    final queryParams = <String, String>{'storeId': storeId};
    if (tableId != null) queryParams['tableId'] = tableId;

    final uri = _apiClient.buildUri('/orders/table', queryParams);
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((json) => UnifiedOrder.fromJson(json)).toList();
    } else {
      throw Exception('Failed to get table orders: ${response.statusCode} ${response.body}');
    }
  }

  /// 주문 상세 조회
  Future<UnifiedOrder> getOrder(String orderId) async {
    final uri = _apiClient.buildUri('/orders/$orderId');
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      return UnifiedOrder.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get order: ${response.statusCode} ${response.body}');
    }
  }

  /// 주문번호로 조회
  Future<UnifiedOrder> getOrderByNumber(String orderNumber) async {
    final uri = _apiClient.buildUri('/orders/number/$orderNumber');
    final response = await http.get(uri, headers: _apiClient.headers);

    if (response.statusCode == 200) {
      return UnifiedOrder.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get order by number: ${response.statusCode} ${response.body}');
    }
  }

  /// 주문 상태 변경
  Future<UnifiedOrder> updateOrderStatus(String orderId, UnifiedOrderStatus status) async {
    final body = {'status': status.name};
    final uri = _apiClient.buildUri('/orders/$orderId/status');
    final response = await http.patch(
      uri,
      headers: _apiClient.headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final updatedOrder = UnifiedOrder.fromJson(jsonDecode(response.body));
      
      // 캐시 업데이트
      _cacheService.updateOrderStatus(orderId, status);
      
      return updatedOrder;
    } else {
      throw Exception('Failed to update order status: ${response.statusCode} ${response.body}');
    }
  }

  /// 조리 상태 변경
  Future<UnifiedOrder> updateCookingStatus(String orderId, CookingStatus cookingStatus) async {
    final body = {'cookingStatus': cookingStatus.name};
    final uri = _apiClient.buildUri('/orders/$orderId/cooking-status');
    final response = await http.patch(
      uri,
      headers: _apiClient.headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final updatedOrder = UnifiedOrder.fromJson(jsonDecode(response.body));
      
      // 캐시 업데이트
      _cacheService.updateOrderCookingStatus(orderId, cookingStatus);
      
      return updatedOrder;
    } else {
      throw Exception('Failed to update cooking status: ${response.statusCode} ${response.body}');
    }
  }

  /// 결제 연결
  Future<UnifiedOrder> linkSale(String orderId, String? saleId) async {
    final body = {'saleId': saleId};
    final uri = _apiClient.buildUri('/orders/$orderId/sale');
    final response = await http.patch(
      uri,
      headers: _apiClient.headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return UnifiedOrder.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to link sale: ${response.statusCode} ${response.body}');
    }
  }

  /// 주문 삭제
  Future<void> deleteOrder(String orderId) async {
    final uri = _apiClient.buildUri('/orders/$orderId');
    final response = await http.delete(uri, headers: _apiClient.headers);

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete order: ${response.statusCode} ${response.body}');
    }
  }

  /// 조리 시작
  Future<UnifiedOrder> startCooking(String orderId) async {
    return updateCookingStatus(orderId, CookingStatus.IN_PROGRESS);
  }

  /// 조리 완료 (자동 알림 발송)
  Future<UnifiedOrder> completeCooking(String orderId) async {
    return updateCookingStatus(orderId, CookingStatus.COMPLETED);
  }

  /// 서빙/픽업 완료
  Future<UnifiedOrder> completeOrder(String orderId, OrderType type) async {
    final status = type == OrderType.TABLE 
        ? UnifiedOrderStatus.SERVED 
        : UnifiedOrderStatus.PICKED_UP;
    return updateOrderStatus(orderId, status);
  }
}

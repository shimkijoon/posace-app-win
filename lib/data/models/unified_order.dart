class UnifiedOrder {
  final String id;
  final String orderNumber;
  final String storeId;
  final OrderType type;
  final UnifiedOrderStatus status;
  final double totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? note;
  
  // 직원 및 세션
  final String? sessionId;
  final String? employeeId;
  
  // 조리 관리
  final CookingStatus? cookingStatus;
  final DateTime? cookingStartedAt;
  final DateTime? cookingCompletedAt;
  final int priority;
  final int estimatedMinutes;
  
  // 결제 연결
  final String? saleId;
  
  // 테이블 주문 특화
  final String? tableId;
  final int? guestCount;
  final int version;
  final DateTime? openedAt;
  final DateTime? closedAt;
  
  // 테이크아웃 특화
  final String? customerName;
  final String? customerPhone;
  final DateTime? scheduledTime;
  final DateTime? pickedUpAt;
  final DateTime? notifiedAt;
  final bool notificationSent;
  
  // 관계 데이터
  final List<UnifiedOrderItem> items;
  final Map<String, dynamic>? table;
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? session;
  final Map<String, dynamic>? sale;

  UnifiedOrder({
    required this.id,
    required this.orderNumber,
    required this.storeId,
    required this.type,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.sessionId,
    this.employeeId,
    this.cookingStatus,
    this.cookingStartedAt,
    this.cookingCompletedAt,
    this.priority = 0,
    this.estimatedMinutes = 15,
    this.saleId,
    this.tableId,
    this.guestCount,
    this.version = 1,
    this.openedAt,
    this.closedAt,
    this.customerName,
    this.customerPhone,
    this.scheduledTime,
    this.pickedUpAt,
    this.notifiedAt,
    this.notificationSent = false,
    this.items = const [],
    this.table,
    this.employee,
    this.session,
    this.sale,
  });

  factory UnifiedOrder.fromJson(Map<String, dynamic> json) {
    // 안전한 숫자 변환 헬퍼 함수
    double safeToDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      } else {
        return 0.0;
      }
    }

    return UnifiedOrder(
      id: json['id'],
      orderNumber: json['orderNumber'],
      storeId: json['storeId'],
      type: OrderType.values.firstWhere((e) => e.name == json['type']),
      status: UnifiedOrderStatus.values.firstWhere((e) => e.name == json['status']),
      totalAmount: safeToDouble(json['totalAmount']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      note: json['note'],
      sessionId: json['sessionId'],
      employeeId: json['employeeId'],
      cookingStatus: json['cookingStatus'] != null 
          ? CookingStatus.values.firstWhere((e) => e.name == json['cookingStatus'])
          : null,
      cookingStartedAt: json['cookingStartedAt'] != null 
          ? DateTime.parse(json['cookingStartedAt']) 
          : null,
      cookingCompletedAt: json['cookingCompletedAt'] != null 
          ? DateTime.parse(json['cookingCompletedAt']) 
          : null,
      priority: json['priority'] ?? 0,
      estimatedMinutes: json['estimatedMinutes'] ?? 15,
      saleId: json['saleId'],
      tableId: json['tableId'],
      guestCount: json['guestCount'],
      version: json['version'] ?? 1,
      openedAt: json['openedAt'] != null ? DateTime.parse(json['openedAt']) : null,
      closedAt: json['closedAt'] != null ? DateTime.parse(json['closedAt']) : null,
      customerName: json['customerName'],
      customerPhone: json['customerPhone'],
      scheduledTime: json['scheduledTime'] != null 
          ? DateTime.parse(json['scheduledTime']) 
          : null,
      pickedUpAt: json['pickedUpAt'] != null 
          ? DateTime.parse(json['pickedUpAt']) 
          : null,
      notifiedAt: json['notifiedAt'] != null 
          ? DateTime.parse(json['notifiedAt']) 
          : null,
      notificationSent: json['notificationSent'] ?? false,
      items: (json['items'] as List<dynamic>?)
          ?.map((item) => UnifiedOrderItem.fromJson(item))
          .toList() ?? [],
      table: json['table'],
      employee: json['employee'],
      session: json['session'],
      sale: json['sale'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'storeId': storeId,
      'type': type.name,
      'status': status.name,
      'totalAmount': totalAmount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'note': note,
      'sessionId': sessionId,
      'employeeId': employeeId,
      'cookingStatus': cookingStatus?.name,
      'cookingStartedAt': cookingStartedAt?.toIso8601String(),
      'cookingCompletedAt': cookingCompletedAt?.toIso8601String(),
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'saleId': saleId,
      'tableId': tableId,
      'guestCount': guestCount,
      'version': version,
      'openedAt': openedAt?.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'pickedUpAt': pickedUpAt?.toIso8601String(),
      'notifiedAt': notifiedAt?.toIso8601String(),
      'notificationSent': notificationSent,
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // copyWith 메서드
  UnifiedOrder copyWith({
    String? id,
    String? orderNumber,
    String? storeId,
    OrderType? type,
    UnifiedOrderStatus? status,
    double? totalAmount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? note,
    String? sessionId,
    String? employeeId,
    CookingStatus? cookingStatus,
    DateTime? cookingStartedAt,
    DateTime? cookingCompletedAt,
    int? priority,
    int? estimatedMinutes,
    String? saleId,
    String? tableId,
    int? guestCount,
    int? version,
    DateTime? openedAt,
    DateTime? closedAt,
    String? customerName,
    String? customerPhone,
    DateTime? scheduledTime,
    DateTime? pickedUpAt,
    DateTime? notifiedAt,
    bool? notificationSent,
    List<UnifiedOrderItem>? items,
    Map<String, dynamic>? table,
    Map<String, dynamic>? employee,
    Map<String, dynamic>? session,
    Map<String, dynamic>? sale,
  }) {
    return UnifiedOrder(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      note: note ?? this.note,
      sessionId: sessionId ?? this.sessionId,
      employeeId: employeeId ?? this.employeeId,
      cookingStatus: cookingStatus ?? this.cookingStatus,
      cookingStartedAt: cookingStartedAt ?? this.cookingStartedAt,
      cookingCompletedAt: cookingCompletedAt ?? this.cookingCompletedAt,
      priority: priority ?? this.priority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      saleId: saleId ?? this.saleId,
      tableId: tableId ?? this.tableId,
      guestCount: guestCount ?? this.guestCount,
      version: version ?? this.version,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      notifiedAt: notifiedAt ?? this.notifiedAt,
      notificationSent: notificationSent ?? this.notificationSent,
      items: items ?? this.items,
      table: table ?? this.table,
      employee: employee ?? this.employee,
      session: session ?? this.session,
      sale: sale ?? this.sale,
    );
  }

  // 상태 확인 헬퍼 메서드
  bool get isPaid => saleId != null;
  bool get isTableOrder => type == OrderType.TABLE;
  bool get isTakeoutOrder => type == OrderType.TAKEOUT;
  bool get isDeliveryOrder => type == OrderType.DELIVERY;
  bool get isCookingInProgress => cookingStatus == CookingStatus.IN_PROGRESS;
  bool get isCookingCompleted => cookingStatus == CookingStatus.COMPLETED;
  bool get isReady => status == UnifiedOrderStatus.READY;
  bool get isCompleted => status == UnifiedOrderStatus.SERVED || status == UnifiedOrderStatus.PICKED_UP;

  // 예상 완료 시간 계산
  DateTime? get estimatedCompletionTime {
    if (cookingStartedAt != null) {
      return cookingStartedAt!.add(Duration(minutes: estimatedMinutes));
    }
    return null;
  }

  // 상태 표시 텍스트
  String get statusDisplayText {
    switch (status) {
      case UnifiedOrderStatus.PENDING:
        return '주문 접수';
      case UnifiedOrderStatus.CONFIRMED:
        return '주문 확정';
      case UnifiedOrderStatus.COOKING:
        return '조리 중';
      case UnifiedOrderStatus.READY:
        return isTakeoutOrder ? '픽업 대기' : '서빙 대기';
      case UnifiedOrderStatus.SERVED:
        return '서빙 완료';
      case UnifiedOrderStatus.PICKED_UP:
        return '픽업 완료';
      case UnifiedOrderStatus.CANCELLED:
        return '취소됨';
      case UnifiedOrderStatus.MODIFIED:
        return '변경됨';
    }
  }

  // 조리 상태 표시 텍스트
  String get cookingStatusDisplayText {
    switch (cookingStatus) {
      case CookingStatus.WAITING:
        return '조리 대기';
      case CookingStatus.IN_PROGRESS:
        return '조리 중';
      case CookingStatus.COMPLETED:
        return '조리 완료';
      case null:
        return '미정';
    }
  }
}

class UnifiedOrderItem {
  final String id;
  final String orderId;
  final String productId;
  final int qty;
  final double price;
  final Map<String, dynamic>? options;
  final String? note;
  final OrderItemStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? cookingStartedAt;
  final DateTime? cookingCompletedAt;
  final DateTime? servedAt;
  final Map<String, dynamic>? product;

  UnifiedOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.qty,
    required this.price,
    this.options,
    this.note,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.cookingStartedAt,
    this.cookingCompletedAt,
    this.servedAt,
    this.product,
  });

  factory UnifiedOrderItem.fromJson(Map<String, dynamic> json) {
    // 안전한 숫자 변환 헬퍼 함수
    double safeToDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      } else {
        return 0.0;
      }
    }

    int safeToInt(dynamic value) {
      if (value is int) {
        return value;
      } else if (value is num) {
        return value.toInt();
      } else if (value is String) {
        return int.tryParse(value) ?? 0;
      } else {
        return 0;
      }
    }

    return UnifiedOrderItem(
      id: json['id'],
      orderId: json['orderId'],
      productId: json['productId'],
      qty: safeToInt(json['qty']),
      price: safeToDouble(json['price']),
      options: json['options'],
      note: json['note'],
      status: OrderItemStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      cookingStartedAt: json['cookingStartedAt'] != null 
          ? DateTime.parse(json['cookingStartedAt']) 
          : null,
      cookingCompletedAt: json['cookingCompletedAt'] != null 
          ? DateTime.parse(json['cookingCompletedAt']) 
          : null,
      servedAt: json['servedAt'] != null 
          ? DateTime.parse(json['servedAt']) 
          : null,
      product: json['product'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'qty': qty,
      'price': price,
      'options': options,
      'note': note,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'cookingStartedAt': cookingStartedAt?.toIso8601String(),
      'cookingCompletedAt': cookingCompletedAt?.toIso8601String(),
      'servedAt': servedAt?.toIso8601String(),
    };
  }

  // 상품명 가져오기
  String get productName => product?['name'] ?? 'Unknown Product';
  
  // 총 가격 계산
  double get totalPrice => price * qty;
}

enum OrderType {
  TABLE,
  TAKEOUT,
  DELIVERY,
}

enum UnifiedOrderStatus {
  PENDING,
  CONFIRMED,
  COOKING,
  READY,
  SERVED,
  PICKED_UP,
  CANCELLED,
  MODIFIED,
}

enum CookingStatus {
  WAITING,
  IN_PROGRESS,
  COMPLETED,
}

enum OrderItemStatus {
  PENDING,
  PREPARING,
  READY,
  SERVED,
  CANCELLED,
}

/// 주문 아이템 생성 요청
class CreateOrderItemRequest {
  final String productId;
  final int quantity;
  final double unitPrice;
  final String? note;

  CreateOrderItemRequest({
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    this.note,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'qty': quantity,
      'price': unitPrice,
      if (note != null) 'note': note,
    };
  }
}
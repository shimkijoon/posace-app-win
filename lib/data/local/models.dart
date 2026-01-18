class CategoryModel {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      name: map['name'] as String,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class ProductModel {
  final String id;
  final String storeId;
  final String categoryId;
  final String name;
  final int price;
  final bool stockEnabled;
  final int? stockQuantity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.price,
    required this.stockEnabled,
    this.stockQuantity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'categoryId': categoryId,
      'name': name,
      'price': price,
      'stockEnabled': stockEnabled ? 1 : 0,
      'stockQuantity': stockQuantity,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // price는 Decimal이므로 문자열 또는 숫자로 올 수 있음
    final priceValue = map['price'];
    final price = priceValue is String
        ? (double.parse(priceValue)).round()
        : (priceValue as num).round();

    return ProductModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      categoryId: map['categoryId'] as String,
      name: map['name'] as String,
      price: price,
      stockEnabled: map['stockEnabled'] is bool
          ? map['stockEnabled'] as bool
          : (map['stockEnabled'] as int) == 1,
      stockQuantity: map['stockQuantity'] as int?,
      isActive: map['isActive'] is bool
          ? map['isActive'] as bool
          : (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class DiscountModel {
  final String id;
  final String storeId;
  final String type; // PRODUCT, CART
  final String? targetId;
  final String name;
  final int rateOrAmount;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscountModel({
    required this.id,
    required this.storeId,
    required this.type,
    this.targetId,
    required this.name,
    required this.rateOrAmount,
    this.startsAt,
    this.endsAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'type': type,
      'targetId': targetId,
      'name': name,
      'rateOrAmount': rateOrAmount,
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory DiscountModel.fromMap(Map<String, dynamic> map) {
    // rateOrAmount는 Decimal이므로 문자열 또는 숫자로 올 수 있음
    final rateOrAmountValue = map['rateOrAmount'];
    final rateOrAmount = rateOrAmountValue is String
        ? (double.parse(rateOrAmountValue)).round()
        : (rateOrAmountValue as num).round();

    return DiscountModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      type: map['type'] as String,
      targetId: map['targetId'] as String?,
      name: map['name'] as String,
      rateOrAmount: rateOrAmount,
      startsAt: map['startsAt'] != null ? DateTime.parse(map['startsAt'] as String) : null,
      endsAt: map['endsAt'] != null ? DateTime.parse(map['endsAt'] as String) : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

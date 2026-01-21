import './models/taxes_models.dart';
import './models/options_models.dart';
import './models/bundle_models.dart';

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
  final String type; // SINGLE, COMBO
  final int price;
  final String? barcode;
  final bool stockEnabled;
  final int? stockQuantity;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  final List<TaxModel> taxes;
  final List<ProductOptionGroupModel> optionGroups;
  final List<BundleItemModel> bundleItems;

  ProductModel({
    required this.id,
    required this.storeId,
    required this.categoryId,
    required this.name,
    required this.type,
    required this.price,
    this.barcode,
    required this.stockEnabled,
    this.stockQuantity,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.taxes = const [],
    this.optionGroups = const [],
    this.bundleItems = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'categoryId': categoryId,
      'name': name,
      'type': type,
      'price': price,
      'barcode': barcode,
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
      type: map['type'] as String? ?? 'SINGLE',
      price: price,
      barcode: map['barcode'] as String?,
      stockEnabled: map['stockEnabled'] is bool
          ? map['stockEnabled'] as bool
          : (map['stockEnabled'] as int) == 1,
      stockQuantity: map['stockQuantity'] as int?,
      isActive: map['isActive'] is bool
          ? map['isActive'] as bool
          : (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      taxes: map['taxes'] != null
          ? (map['taxes'] as List).map((e) => TaxModel.fromMap(e as Map<String, dynamic>)).toList()
          : [],
      optionGroups: map['optionGroups'] != null
          ? (map['optionGroups'] as List).map((e) {
              final groupMap = e as Map<String, dynamic>;
              final options = groupMap['options'] != null
                  ? (groupMap['options'] as List).map((o) => ProductOptionModel.fromMap(o as Map<String, dynamic>)).toList()
                  : <ProductOptionModel>[];
              return ProductOptionGroupModel.fromMap(groupMap, options: options);
            }).toList()
          : [],
      bundleItems: map['bundleItems'] != null
          ? (map['bundleItems'] as List).map((e) => BundleItemModel.fromMap(e as Map<String, dynamic>)).toList()
          : [],
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

class SaleModel {
  final String id;
  final String? clientSaleId;
  final String storeId;
  final String? posId;
  final int totalAmount;
  final int paidAmount;
  final String paymentMethod;
  final String status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  final int taxAmount;

  SaleModel({
    required this.id,
    this.clientSaleId,
    required this.storeId,
    this.posId,
    required this.totalAmount,
    required this.paidAmount,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.syncedAt,
    this.taxAmount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientSaleId': clientSaleId,
      'storeId': storeId,
      'posId': posId,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'taxAmount': taxAmount,
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'] as String,
      clientSaleId: map['clientSaleId'] as String?,
      storeId: map['storeId'] as String,
      posId: map['posId'] as String?,
      totalAmount: map['totalAmount'] as int,
      paidAmount: map['paidAmount'] as int,
      paymentMethod: map['paymentMethod'] as String,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      syncedAt: map['syncedAt'] != null ? DateTime.parse(map['syncedAt'] as String) : null,
      taxAmount: map['taxAmount'] as int? ?? 0,
    );
  }
}

class SaleItemModel {
  final String id;
  final String saleId;
  final String productId;
  final int qty;
  final int price;
  final int discountAmount;

  SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.qty,
    required this.price,
    required this.discountAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'qty': qty,
      'price': price,
      'discountAmount': discountAmount,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'] as String,
      saleId: map['saleId'] as String,
      productId: map['productId'] as String,
      qty: map['qty'] as int,
      price: map['price'] as int,
      discountAmount: map['discountAmount'] as int,
    );
  }
}

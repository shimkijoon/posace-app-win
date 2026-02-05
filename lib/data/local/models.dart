import 'dart:convert';
import './models/taxes_models.dart';
import './models/options_models.dart';
import './models/bundle_models.dart';
import './models/employee_model.dart';
import './models/session_model.dart';
import './models/payment_model.dart';
import './models/store_settings_model.dart';

export './models/taxes_models.dart';
export './models/options_models.dart';
export './models/bundle_models.dart';
export './models/employee_model.dart';
export './models/session_model.dart';
export './models/payment_model.dart';
export './models/store_settings_model.dart';


class CategoryModel {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;
  final bool allowProductDiscount;
  final String? kitchenStationId;
  final bool isKitchenPrintEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  CategoryModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sortOrder,
    this.allowProductDiscount = true,
    this.kitchenStationId,
    this.isKitchenPrintEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'sortOrder': sortOrder,
      'allowProductDiscount': allowProductDiscount ? 1 : 0,
      'kitchenStationId': kitchenStationId,
      'isKitchenPrintEnabled': isKitchenPrintEnabled ? 1 : 0,
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
      allowProductDiscount: map['allowProductDiscount'] == 1 || map['allowProductDiscount'] == true,
      kitchenStationId: map['kitchenStationId'] as String?,
      isKitchenPrintEnabled: map['isKitchenPrintEnabled'] == 1 || map['isKitchenPrintEnabled'] == true || map['isKitchenPrintEnabled'] == null,
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

  final String? kitchenStationId;
  final bool isKitchenPrintEnabled;

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
    this.kitchenStationId,
    this.isKitchenPrintEnabled = true,
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
      'kitchenStationId': kitchenStationId,
      'isKitchenPrintEnabled': isKitchenPrintEnabled ? 1 : 0,
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
      kitchenStationId: map['kitchenStationId'] as String?,
      isKitchenPrintEnabled: map['isKitchenPrintEnabled'] == 1 || map['isKitchenPrintEnabled'] == true || map['isKitchenPrintEnabled'] == null,
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
  final int priority;
  final List<String> productIds;
  final List<String> categoryIds;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String status;
  final String method; // PERCENTAGE, AMOUNT
  final DateTime createdAt;
  final DateTime updatedAt;

  DiscountModel({
    required this.id,
    required this.storeId,
    required this.type,
    this.targetId,
    required this.name,
    required this.rateOrAmount,
    this.priority = 0,
    this.productIds = const [],
    this.categoryIds = const [],
    this.startsAt,
    this.endsAt,
    required this.status,
    required this.method,
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
      'priority': priority,
      'productIds': json.encode(productIds),
      'categoryIds': json.encode(categoryIds),
      'startsAt': startsAt?.toIso8601String(),
      'endsAt': endsAt?.toIso8601String(),
      'status': status,
      'method': method,
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
      priority: map['priority'] as int? ?? 0,
      productIds: _parseIds(map['productIds'] ?? map['products']),
      categoryIds: _parseIds(map['categoryIds'] ?? map['categories']),
      startsAt: map['startsAt'] != null ? DateTime.parse(map['startsAt'] as String) : null,
      endsAt: map['endsAt'] != null ? DateTime.parse(map['endsAt'] as String) : null,
      status: map['status'] as String,
      method: map['method'] as String? ?? 'PERCENTAGE',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static List<String> _parseIds(dynamic value) {
    if (value == null) return [];
    if (value is String) {
      try {
        final decoded = json.decode(value);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    if (value is List) {
      return value.map((e) {
        if (e is Map) return e['id']?.toString() ?? '';
        return e.toString();
      }).where((id) => id.isNotEmpty).toList();
    }
    return [];
  }
}

class MemberModel {
  final String id;
  final String storeId;
  final String name;
  final String phone;
  final int points;
  final DateTime createdAt;
  final DateTime updatedAt;

  MemberModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.phone,
    this.points = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'phone': phone,
      'points': points,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MemberModel.fromMap(Map<String, dynamic> map) {
    // points can be Decimal (String) or int
    final pointsValue = map['points'];
    final points = pointsValue is String
        ? (double.tryParse(pointsValue)?.round() ?? 0)
        : (pointsValue as num?)?.round() ?? 0;

    return MemberModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      points: points,
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
  final String? sessionId; // Added
  final String? employeeId; // Added
  final String? memberId;
  final int totalAmount;
  final int paidAmount;
  final String? paymentMethod; // Made nullable
  final String status;
  final DateTime createdAt;
  final DateTime? syncedAt;

  final int taxAmount;
  final int discountAmount; // Total discount amount
  final String? cartDiscountsJson; // JSON array of items {name, amount}
  final int memberPointsEarned;

  final List<SalePaymentModel> payments; // Added
  final DateTime? saleDate;
  final String? saleTime;

  SaleModel({
    required this.id,
    this.clientSaleId,
    required this.storeId,
    this.posId,
    this.sessionId,
    this.employeeId,
    this.memberId,
    required this.totalAmount,
    required this.paidAmount,
    this.paymentMethod,
    required this.status,
    required this.createdAt,
    this.syncedAt,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.cartDiscountsJson,
    this.memberPointsEarned = 0,
    this.payments = const [],
    this.saleDate,
    this.saleTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientSaleId': clientSaleId,
      'storeId': storeId,
      'posId': posId,
      'sessionId': sessionId,
      'employeeId': employeeId,
      'memberId': memberId,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'paymentMethod': paymentMethod,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'syncedAt': syncedAt?.toIso8601String(),
      'taxAmount': taxAmount,
      'discountAmount': discountAmount,
      'cartDiscountsJson': cartDiscountsJson,
      'memberPointsEarned': memberPointsEarned,
      'saleDate': saleDate?.toIso8601String(),
      'saleTime': saleTime,
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map, {List<SalePaymentModel> payments = const []}) {
    return SaleModel(
      id: map['id'] as String,
      clientSaleId: map['clientSaleId'] as String?,
      storeId: map['storeId'] as String,
      posId: map['posId'] as String?,
      sessionId: map['sessionId'] as String?,
      employeeId: map['employeeId'] as String?,
      memberId: map['memberId'] as String?,
      totalAmount: map['totalAmount'] as int,
      paidAmount: map['paidAmount'] as int,
      paymentMethod: map['paymentMethod'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      syncedAt: map['syncedAt'] != null ? DateTime.parse(map['syncedAt'] as String) : null,
      taxAmount: map['taxAmount'] as int? ?? 0,
      discountAmount: map['discountAmount'] as int? ?? 0,
      cartDiscountsJson: map['cartDiscountsJson'] as String?,
      memberPointsEarned: map['memberPointsEarned'] as int? ?? 0,

      saleDate: map['saleDate'] != null ? DateTime.parse(map['saleDate'] as String) : null,
      saleTime: map['saleTime'] as String?,
      payments: payments,
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
  final String? discountsJson; // JSON array of {name, amount}

  SaleItemModel({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.qty,
    required this.price,
    required this.discountAmount,
    this.discountsJson,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'productId': productId,
      'qty': qty,
      'price': price,
      'discountAmount': discountAmount,
      'discountsJson': discountsJson,
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
      discountsJson: map['discountsJson'] as String?,
    );
  }
}

class KitchenStationModel {
  final String id;
  final String storeId;
  final String name;
  final String deviceType; // PRINTER, KDS, NONE
  final String? deviceConfig; // JSON string
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  KitchenStationModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.deviceType,
    this.deviceConfig,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'deviceType': deviceType,
      'deviceConfig': deviceConfig,
      'isDefault': isDefault ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory KitchenStationModel.fromMap(Map<String, dynamic> map) {
    return KitchenStationModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      name: map['name'] as String,
      deviceType: map['deviceType'] as String? ?? 'PRINTER',
      deviceConfig: map['deviceConfig'] as String?,
      isDefault: map['isDefault'] == 1 || map['isDefault'] == true,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

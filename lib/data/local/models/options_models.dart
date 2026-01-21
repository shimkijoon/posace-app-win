class ProductOptionGroupModel {
  final String id;
  final String productId;
  final String name;
  final bool isRequired;
  final bool isMultiSelect;
  final int sortOrder;
  final List<ProductOptionModel> options;

  ProductOptionGroupModel({
    required this.id,
    required this.productId,
    required this.name,
    required this.isRequired,
    required this.isMultiSelect,
    required this.sortOrder,
    this.options = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'name': name,
      'isRequired': isRequired ? 1 : 0,
      'isMultiSelect': isMultiSelect ? 1 : 0,
      'sortOrder': sortOrder,
    };
  }

  factory ProductOptionGroupModel.fromMap(Map<String, dynamic> map, {List<ProductOptionModel> options = const []}) {
    return ProductOptionGroupModel(
      id: map['id'] as String,
      productId: map['productId'] as String,
      name: map['name'] as String,
      isRequired: map['isRequired'] is bool
          ? map['isRequired'] as bool
          : map['isRequired'] == 1,
      isMultiSelect: map['isMultiSelect'] is bool
          ? map['isMultiSelect'] as bool
          : map['isMultiSelect'] == 1,
      sortOrder: map['sortOrder'] as int,
      options: options,
    );
  }
}

class ProductOptionModel {
  final String id;
  final String groupId;
  final String name;
  final double priceAdjustment;
  final int sortOrder;

  ProductOptionModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.priceAdjustment,
    required this.sortOrder,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'groupId': groupId,
      'name': name,
      'priceAdjustment': priceAdjustment,
      'sortOrder': sortOrder,
    };
  }

  factory ProductOptionModel.fromMap(Map<String, dynamic> map) {
    return ProductOptionModel(
      id: map['id'] as String,
      groupId: map['groupId'] as String,
      name: map['name'] as String,
      priceAdjustment: map['priceAdjustment'] is String
          ? double.parse(map['priceAdjustment'] as String)
          : (map['priceAdjustment'] as num).toDouble(),
      sortOrder: map['sortOrder'] as int,
    );
  }
}

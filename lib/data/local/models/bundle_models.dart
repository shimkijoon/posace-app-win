import '../models.dart';

class BundleItemModel {
  final String id;
  final String parentProductId;
  final String componentProductId;
  final int quantity;
  final double priceAdjustment;
  final ProductModel? componentProduct;

  BundleItemModel({
    required this.id,
    required this.parentProductId,
    required this.componentProductId,
    required this.quantity,
    required this.priceAdjustment,
    this.componentProduct,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'parentProductId': parentProductId,
      'componentProductId': componentProductId,
      'quantity': quantity,
      'priceAdjustment': priceAdjustment,
    };
  }

  factory BundleItemModel.fromMap(Map<String, dynamic> map, {ProductModel? componentProduct}) {
    return BundleItemModel(
      id: map['id'] as String,
      parentProductId: map['parentProductId'] as String,
      componentProductId: map['componentProductId'] as String,
      quantity: map['quantity'] as int,
      priceAdjustment: map['priceAdjustment'] is String
          ? double.parse(map['priceAdjustment'] as String)
          : (map['priceAdjustment'] as num).toDouble(),
      componentProduct: componentProduct,
    );
  }
}

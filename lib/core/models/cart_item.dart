import '../../data/local/models.dart';

class CartItem {
  final ProductModel product;
  final int quantity;
  final List<DiscountModel> appliedDiscounts;
  final int? customPrice; // 수정된 가격 (할인 적용 후)

  CartItem({
    required this.product,
    required this.quantity,
    List<DiscountModel>? appliedDiscounts,
    this.customPrice,
  }) : appliedDiscounts = appliedDiscounts ?? [];

  int get unitPrice => customPrice ?? product.price;
  int get totalPrice => unitPrice * quantity;
  
  int get discountAmount {
    if (appliedDiscounts.isEmpty) return 0;
    int totalDiscount = 0;
    for (final discount in appliedDiscounts) {
      if (discount.type == 'PRODUCT' && discount.targetId == product.id) {
        // 상품 할인
        totalDiscount += discount.rateOrAmount * quantity;
      }
    }
    return totalDiscount;
  }

  int get finalPrice => totalPrice - discountAmount;

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
    List<DiscountModel>? appliedDiscounts,
    int? customPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      appliedDiscounts: appliedDiscounts ?? this.appliedDiscounts,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}

import '../../data/local/models.dart';
import '../../data/local/models/options_models.dart';

class CartItem {
  final ProductModel product;
  final int quantity;
  final List<DiscountModel> appliedDiscounts;
  final List<ProductOptionModel> selectedOptions;
  final int? customPrice; // 수정된 가격 (할인 적용 전, 옵션 포함 가격)

  CartItem({
    required this.product,
    required this.quantity,
    List<DiscountModel>? appliedDiscounts,
    List<ProductOptionModel>? selectedOptions,
    this.customPrice,
  })  : appliedDiscounts = appliedDiscounts ?? [],
        selectedOptions = selectedOptions ?? [];

  // 기본 가격 + 선택된 옵션 추가 금액
  int get baseAndOptionsPrice {
    if (customPrice != null) return customPrice!;
    double total = product.price.toDouble();
    for (final option in selectedOptions) {
      total += option.priceAdjustment;
    }
    return total.round();
  }

  int get unitPrice => baseAndOptionsPrice;
  int get totalPrice => unitPrice * quantity;

  int get discountAmount {
    if (appliedDiscounts.isEmpty) return 0;
    int totalDiscount = 0;
    for (final discount in appliedDiscounts) {
      if (discount.type == 'PRODUCT' || discount.type == 'CATEGORY') {
        if (discount.method == 'PERCENTAGE') {
          // 퍼센트 할인
          totalDiscount += (baseAndOptionsPrice * (discount.rateOrAmount / 100)).round() * quantity;
        } else {
          // 정액 할인
          totalDiscount += discount.rateOrAmount * quantity;
        }
      }
    }
    return totalDiscount;
  }

  int get finalPrice => (totalPrice - discountAmount).clamp(0, double.infinity).toInt();

  // 세금 계산
  // Inclusive Tax (포함세): 가격에 이미 포함됨. 역산 필요. (e.g. 한국 VAT)
  // Exclusive Tax (별도세): 가격에 추가됨. (e.g. 미국 Sales Tax)
  
  double get inclusiveTaxAmount {
    double totalTax = 0;
    for (final tax in product.taxes) {
      if (tax.isInclusive) {
        // tax_amount = final_price - (final_price / (1 + rate))
        totalTax += finalPrice - (finalPrice / (1 + (tax.rate / 100)));
      }
    }
    return totalTax;
  }

  double get exclusiveTaxAmount {
    double totalTax = 0;
    for (final tax in product.taxes) {
      if (!tax.isInclusive) {
        // tax_amount = final_price * rate
        totalTax += finalPrice * (tax.rate / 100);
      }
    }
    return totalTax;
  }

  CartItem copyWith({
    ProductModel? product,
    int? quantity,
    List<DiscountModel>? appliedDiscounts,
    List<ProductOptionModel>? selectedOptions,
    int? customPrice,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      appliedDiscounts: appliedDiscounts ?? this.appliedDiscounts,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}

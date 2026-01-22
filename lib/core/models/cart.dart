import 'cart_item.dart';
import '../../data/local/models.dart';
import '../../data/local/models/options_models.dart';

class Cart {
  final List<CartItem> items;
  final List<DiscountModel> cartDiscounts; // 장바구니 전체 할인

  Cart({
    List<CartItem>? items,
    List<DiscountModel>? cartDiscounts,
  })  : items = items ?? [],
        cartDiscounts = cartDiscounts ?? [];

  factory Cart.empty() => Cart(items: [], cartDiscounts: []);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  // 소계: 할인 전 정가 합계 (Gross Subtotal, 옵션 포함)
  int get subtotal {
    final amount = items.fold(0, (sum, item) => sum + item.totalPrice);
    return amount;
  }

  // 상품별 할인 합계
  int get productDiscountTotal {
    return items.fold(0, (sum, item) => sum + item.discountAmount);
  }

  // 장바구니 전체 할인 합계
  int get cartDiscountTotal {
    if (items.isEmpty || cartDiscounts.isEmpty) return 0;
    int totalDiscount = 0;
    for (final discount in cartDiscounts) {
      if (discount.type == 'CART') {
        totalDiscount += discount.rateOrAmount;
      }
    }
    return totalDiscount;
  }

  // 총 할인액 (상품 할인 + 장바구니 할인)
  int get totalDiscountAmount => productDiscountTotal + cartDiscountTotal;

  // 세금 합계
  int get totalTax {
    double total = items.fold(0.0, (sum, item) => sum + item.exclusiveTaxAmount);
    return total.round();
  }

  // 포함세 합계 (참고용)
  int get totalInclusiveTax {
    double total = items.fold(0.0, (sum, item) => sum + item.inclusiveTaxAmount);
    return total.round();
  }

  // 최종 합계: (소계 - 총 할인액) + 별도세
  int get total {
    final netAmount = (subtotal - totalDiscountAmount).clamp(0, double.infinity);
    final result = (netAmount + totalTax).round();

    // 디버그 로그 출력 (사용자 요청)
    if (items.isNotEmpty) {
      print('--- [Cart Calculation Debug] ---');
      print('Items Count: ${items.length}');
      print('Gross Subtotal: $subtotal');
      print('Product Discounts: $productDiscountTotal');
      print('Cart Discounts: $cartDiscountTotal');
      print('Total Discount: $totalDiscountAmount');
      print('Total Tax (Exclusive): $totalTax');
      print('Inclusive Tax (Subtotal included): $totalInclusiveTax');
      print('Final Total: $result');
      print('--------------------------------');
    }

    return result;
  }

  bool get isEmpty => items.isEmpty;

  Cart addItem(ProductModel product, {int quantity = 1, List<ProductOptionModel>? selectedOptions}) {
    // 옵션이 다르면 별도 항목으로 취급
    final existingIndex = items.indexWhere((item) {
      if (item.product.id != product.id) return false;
      if (item.selectedOptions.length != (selectedOptions?.length ?? 0)) return false;
      
      // 옵션 ID들 비교
      final itemOptionIds = item.selectedOptions.map((o) => o.id).toSet();
      final newOptionIds = selectedOptions?.map((o) => o.id).toSet() ?? {};
      return itemOptionIds.difference(newOptionIds).isEmpty;
    });

    if (existingIndex >= 0) {
      final existingItem = items[existingIndex];
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
    } else {
      return Cart(
        items: [
          ...items,
          CartItem(
            product: product,
            quantity: quantity,
            selectedOptions: selectedOptions,
          )
        ],
        cartDiscounts: cartDiscounts,
      );
    }
  }

  Cart updateItemQuantity(String productId, int quantity, {List<ProductOptionModel>? selectedOptions}) {
    if (quantity <= 0) {
      return removeItem(productId, selectedOptions: selectedOptions);
    }

    final index = items.indexWhere((item) {
      if (item.product.id != productId) return false;
      if (selectedOptions == null) return true; // 기본적으로 첫 번째 발견되는 동일 ID 항목
      
      final itemOptionIds = item.selectedOptions.map((o) => o.id).toSet();
      final targetOptionIds = selectedOptions.map((o) => o.id).toSet();
      return itemOptionIds.difference(targetOptionIds).isEmpty;
    });
    
    if (index < 0) return this;

    final updatedItems = List<CartItem>.from(items);
    updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
    return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
  }

  Cart removeItem(String productId, {List<ProductOptionModel>? selectedOptions}) {
    return Cart(
      items: items.where((item) {
        if (item.product.id != productId) return true;
        if (selectedOptions == null) return false; // 모든 옵션 조합 삭제? (보통 하나씩 삭제함)
        
        final itemOptionIds = item.selectedOptions.map((o) => o.id).toSet();
        final targetOptionIds = selectedOptions.map((o) => o.id).toSet();
        return !itemOptionIds.difference(targetOptionIds).isEmpty || !targetOptionIds.difference(itemOptionIds).isEmpty;
      }).toList(),
      cartDiscounts: cartDiscounts,
    );
  }

  Cart clear() {
    return Cart(items: [], cartDiscounts: []);
  }

  Cart applyDiscounts(List<DiscountModel> discounts) {
    final now = DateTime.now();

    // 유효한 할인만 필터링하고 중복 제거 (ID 기준)
    final Map<String, DiscountModel> uniqueDiscounts = {};
    for (final d in discounts) {
      if (d.status != 'ACTIVE') continue;
      if (d.startsAt != null && d.startsAt!.isAfter(now)) continue;
      if (d.endsAt != null && d.endsAt!.isBefore(now)) continue;
      
      // 이미 같은 이름과 금액의 장바구니 할인이 있다면 중복으로 간주 (데이터 베이스 동기화 꼬임 방지)
      final key = '${d.type}_${d.name}_${d.rateOrAmount}';
      if (d.type == 'CART') {
        if (!uniqueDiscounts.containsKey(key)) {
          uniqueDiscounts[key] = d;
        }
      } else {
        // 상품 할인은 ID 기반 중복 제거가 안전
        uniqueDiscounts[d.id] = d;
      }
    }

    final activeDiscounts = uniqueDiscounts.values.toList();

    final productDiscounts = activeDiscounts.where((d) => d.type == 'PRODUCT').toList();
    final cartDiscounts = activeDiscounts.where((d) => d.type == 'CART').toList();

    final updatedItems = items.map((item) {
      final applicableDiscounts = productDiscounts.where((d) => d.targetId == item.product.id).toList();

      return item.copyWith(appliedDiscounts: applicableDiscounts);
    }).toList();

    return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
  }
}

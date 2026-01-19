import 'cart_item.dart';
import '../../data/local/models.dart';

class Cart {
  final List<CartItem> items;
  final List<DiscountModel> cartDiscounts; // 장바구니 전체 할인

  Cart({
    List<CartItem>? items,
    List<DiscountModel>? cartDiscounts,
  })  : items = items ?? [],
        cartDiscounts = cartDiscounts ?? [];

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  // 소계: 할인 전 정가 합계 (Gross Subtotal)
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
  
  // 최종 합계: 소계 - 총 할인액
  int get total {
    final result = (subtotal - totalDiscountAmount).clamp(0, double.infinity).toInt();
    
    // 디버그 로그 출력 (사용자 요청)
    if (items.isNotEmpty) {
      print('--- [Cart Calculation Debug] ---');
      print('Items Count: ${items.length}');
      print('Gross Subtotal: $subtotal');
      print('Product Discounts: $productDiscountTotal');
      print('Cart Discounts: $cartDiscountTotal');
      print('Total Discount: $totalDiscountAmount');
      print('Final Total: $result');
      print('--------------------------------');
    }
    
    return result;
  }

  bool get isEmpty => items.isEmpty;

  Cart addItem(ProductModel product, {int quantity = 1}) {
    final existingIndex = items.indexWhere((item) => item.product.id == product.id);
    
    if (existingIndex >= 0) {
      final existingItem = items[existingIndex];
      final updatedItems = List<CartItem>.from(items);
      updatedItems[existingIndex] = existingItem.copyWith(
        quantity: existingItem.quantity + quantity,
      );
      return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
    } else {
      return Cart(
        items: [...items, CartItem(product: product, quantity: quantity)],
        cartDiscounts: cartDiscounts,
      );
    }
  }

  Cart updateItemQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      return removeItem(productId);
    }
    
    final index = items.indexWhere((item) => item.product.id == productId);
    if (index < 0) return this;
    
    final updatedItems = List<CartItem>.from(items);
    updatedItems[index] = updatedItems[index].copyWith(quantity: quantity);
    return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
  }

  Cart removeItem(String productId) {
    return Cart(
      items: items.where((item) => item.product.id != productId).toList(),
      cartDiscounts: cartDiscounts,
    );
  }

  Cart clear() {
    return Cart(items: [], cartDiscounts: []);
  }

  Cart applyDiscounts(List<DiscountModel> discounts) {
    final now = DateTime.now();
    
    // 유효한 할인만 필터링 (상태가 ACTIVE이고 기간 내에 있는 경우)
    final activeDiscounts = discounts.where((d) {
      if (d.status != 'ACTIVE') return false;
      if (d.startsAt != null && d.startsAt!.isAfter(now)) return false;
      if (d.endsAt != null && d.endsAt!.isBefore(now)) return false;
      return true;
    }).toList();

    final productDiscounts = activeDiscounts.where((d) => d.type == 'PRODUCT').toList();
    
    // 장바구니 할인은 장바구니가 비어있더라도 active한 것들을 유지 (UI 표시용)
    final cartDiscounts = activeDiscounts.where((d) => d.type == 'CART').toList();
    
    final updatedItems = items.map((item) {
      final applicableDiscounts = productDiscounts
          .where((d) => d.targetId == item.product.id)
          .toList();
      
      return item.copyWith(appliedDiscounts: applicableDiscounts);
    }).toList();
    
    return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
  }
}

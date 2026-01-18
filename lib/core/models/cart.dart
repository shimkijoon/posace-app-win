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
  
  int get subtotal => items.fold(0, (sum, item) => sum + item.finalPrice);
  
  int get cartDiscountAmount {
    if (cartDiscounts.isEmpty) return 0;
    int totalDiscount = 0;
    for (final discount in cartDiscounts) {
      if (discount.type == 'CART') {
        totalDiscount += discount.rateOrAmount;
      }
    }
    return totalDiscount;
  }
  
  int get total => (subtotal - cartDiscountAmount).clamp(0, double.infinity).toInt();

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
    final productDiscounts = discounts.where((d) => d.type == 'PRODUCT').toList();
    final cartDiscounts = discounts.where((d) => d.type == 'CART').toList();
    
    final updatedItems = items.map((item) {
      final applicableDiscounts = productDiscounts
          .where((d) => d.targetId == item.product.id)
          .toList();
      
      return item.copyWith(appliedDiscounts: applicableDiscounts);
    }).toList();
    
    return Cart(items: updatedItems, cartDiscounts: cartDiscounts);
  }
}

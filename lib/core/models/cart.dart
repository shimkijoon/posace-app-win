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
        if (discount.method == 'PERCENTAGE') {
          // 장바구니 전체 퍼센트 할인
          totalDiscount += (subtotal * (discount.rateOrAmount / 100)).round();
        } else {
          // 장바구니 전체 정액 할인
          totalDiscount += discount.rateOrAmount;
        }
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

  /// JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'items': items.map((item) => {
        'product': item.product.toMap(),
        'quantity': item.quantity,
        'selectedOptions': item.selectedOptions.map((opt) => opt.toMap()).toList(),
        'appliedDiscounts': item.appliedDiscounts.map((d) => d.toMap()).toList(),
        'customPrice': item.customPrice,
      }).toList(),
      'cartDiscounts': cartDiscounts.map((d) => d.toMap()).toList(),
    };
  }

  /// JSON에서 복원
  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      items: (json['items'] as List<dynamic>?)?.map((itemJson) {
        final product = ProductModel.fromMap(itemJson['product'] as Map<String, dynamic>);
        final selectedOptions = (itemJson['selectedOptions'] as List<dynamic>?)
            ?.map((opt) => ProductOptionModel.fromMap(opt as Map<String, dynamic>))
            .toList() ?? [];
        final appliedDiscounts = (itemJson['appliedDiscounts'] as List<dynamic>?)
            ?.map((d) => DiscountModel.fromMap(d as Map<String, dynamic>))
            .toList() ?? [];
        return CartItem(
          product: product,
          quantity: itemJson['quantity'] as int,
          selectedOptions: selectedOptions,
          appliedDiscounts: appliedDiscounts,
          customPrice: itemJson['customPrice'] as int?,
        );
      }).toList() ?? [],
      cartDiscounts: (json['cartDiscounts'] as List<dynamic>?)
          ?.map((d) => DiscountModel.fromMap(d as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Cart applyDiscounts(List<DiscountModel> discounts, List<CategoryModel> categories) {
    final now = DateTime.now();

    // 1. 유효한 할인만 필터링 (ID 기준 중복 제거)
    final Map<String, DiscountModel> activeDiscountsMap = {};
    for (final d in discounts) {
      if (d.status != 'ACTIVE') continue;
      if (d.startsAt != null && d.startsAt!.isAfter(now)) continue;
      if (d.endsAt != null && d.endsAt!.isBefore(now)) continue;
      activeDiscountsMap[d.id] = d;
    }

    final activeDiscounts = activeDiscountsMap.values.toList();
    final productDiscounts = activeDiscounts.where((d) => d.type == 'PRODUCT').toList();
    final categoryDiscounts = activeDiscounts.where((d) => d.type == 'CATEGORY').toList();
    final cartDiscountsList = activeDiscounts.where((d) => d.type == 'CART').toList();

    // 2. 상품별 할인 적용
    final updatedItems = items.map((item) {
      final itemCategoryDiscounts = categoryDiscounts.where((d) => d.categoryIds.contains(item.product.categoryId)).toList();
      final itemProductDiscounts = productDiscounts.where((d) => d.productIds.contains(item.product.id) || d.targetId == item.product.id).toList();

      // 최고 우선순위 카테고리 할인 선택
      DiscountModel? bestCategoryDiscount;
      if (itemCategoryDiscounts.isNotEmpty) {
        bestCategoryDiscount = itemCategoryDiscounts.reduce((a, b) => a.priority >= b.priority ? a : b);
      }

      // 최고 우선순위 상품 할인 선택
      DiscountModel? bestProductDiscount;
      if (itemProductDiscounts.isNotEmpty) {
        bestProductDiscount = itemProductDiscounts.reduce((a, b) => a.priority >= b.priority ? a : b);
      }

      List<DiscountModel> applied = [];
      
      if (bestCategoryDiscount != null) {
        applied.add(bestCategoryDiscount);
        
        // 카테고리 설정 확인 (상품 할인 중복 허용 여부)
        final category = categories.firstWhere((c) => c.id == item.product.categoryId, 
          orElse: () => CategoryModel(id: '', storeId: '', name: '', sortOrder: 0, createdAt: DateTime.now(), updatedAt: DateTime.now()));
        
        if (category.allowProductDiscount && bestProductDiscount != null) {
          applied.add(bestProductDiscount);
        }
      } else if (bestProductDiscount != null) {
        // 카테고리 할인이 없으면 상품 할인 적용
        applied.add(bestProductDiscount);
      }

      return item.copyWith(appliedDiscounts: applied);
    }).toList();

    // 3. 장바구니 할인은 중복 가능? (일단 기존 로직 유지하되 ID 기준 필터링됨)
    return Cart(items: updatedItems, cartDiscounts: cartDiscountsList);
  }
}

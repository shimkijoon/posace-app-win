import 'package:flutter/material.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/i18n/locale_helper.dart';

typedef ValueChanged2<T1, T2> = void Function(T1 value1, T2 value2);

class CartSidebar extends StatelessWidget {
  const CartSidebar({
    super.key,
    required this.cart,
    required this.onQuantityChanged,
    required this.onItemRemove,
    required this.onClear,
    required this.onCheckout,
    this.countryCode = 'KR',
  });

  final Cart cart;
  final ValueChanged2<String, int> onQuantityChanged;
  final ValueChanged<String> onItemRemove;
  final VoidCallback onClear;
  final VoidCallback onCheckout;
  final String countryCode;

  String _formatPrice(int price) {
    return LocaleHelper.getCurrencyFormat(countryCode).format(price);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.primary,
              border: Border(bottom: BorderSide(color: AppTheme.primaryDark, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.cart,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (!cart.isEmpty)
                  TextButton.icon(
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text(AppLocalizations.of(context)!.clear),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 장바구니 아이템 리스트
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.cartEmpty,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _CartItemCard(
                        item: item,
                        onQuantityChanged: (quantity) =>
                            onQuantityChanged(item.product.id, quantity),
                        onRemove: () => onItemRemove(item.product.id),
                        formatPrice: _formatPrice,
                      );
                    },
                  ),
          ),

          // 하단 요약 및 결제 버튼
          if (!cart.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(
                  top: BorderSide(color: AppTheme.border, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // 할인 정보
                  if (cart.cartDiscountTotal > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.discount,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          '-${_formatPrice(cart.cartDiscountTotal)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.success,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  
                  // 총액
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.translate('sales.totalAmount'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        _formatPrice(cart.total),
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // 결제 버튼
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onCheckout,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 12,
                        shadowColor: AppTheme.primary.withOpacity(0.4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            AppLocalizations.of(context)!.proceedToPayment,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.formatPrice,
  });

  final CartItem item;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final String Function(int) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상품명 및 삭제 버튼
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
                color: AppTheme.textSecondary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 가격 및 수량 조절
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 단가
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.discountAmount > 0) ...[
                    Text(
                      formatPrice(item.product.price),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    formatPrice(item.unitPrice),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                  ),
                ],
              ),
              
              // 수량 조절 버튼
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: item.quantity > 1
                          ? () => onQuantityChanged(item.quantity - 1)
                          : null,
                      icon: const Icon(Icons.remove, size: 18),
                      color: AppTheme.textPrimary,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${item.quantity}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onQuantityChanged(item.quantity + 1),
                      icon: const Icon(Icons.add, size: 18),
                      color: AppTheme.primary,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // 할인 정보
          if (item.discountAmount > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${AppLocalizations.of(context)!.discount}: -${formatPrice(item.discountAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          
          // 소계
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${AppLocalizations.of(context)!.translate('sales.subtotal')}: ${formatPrice(item.finalPrice)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

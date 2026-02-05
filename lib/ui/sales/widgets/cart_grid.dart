import 'package:flutter/material.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/local/models.dart';
import '../../../core/i18n/locale_helper.dart';

typedef ValueChanged2<T1, T2> = void Function(T1 value1, T2 value2);

class CartGrid extends StatefulWidget {
  const CartGrid({
    super.key,
    required this.cart,
    required this.onQuantityChanged,
    required this.onItemRemove,
    this.countryCode = 'KR',
  });

  final Cart cart;
  final ValueChanged2<String, int> onQuantityChanged;
  final ValueChanged<String> onItemRemove;
  final String countryCode;

  @override
  State<CartGrid> createState() => _CartGridState();
}

class _CartGridState extends State<CartGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollUp = false;
  bool _canScrollDown = false;
  String? _selectedItemId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateScrollButtons);
    // 위젯이 빌드된 후 스크롤 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateScrollButtons();
      }
    });
  }

  @override
  void didUpdateWidget(CartGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 위젯이 업데이트된 후 스크롤 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateScrollButtons();
        
        // 상품이 추가되었을 때 하단으로 자동 스크롤
        if (widget.cart.items.length > oldWidget.cart.items.length) {
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollButtons);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateScrollButtons() {
    if (!_scrollController.hasClients) {
      setState(() {
        _canScrollUp = false;
        _canScrollDown = false;
      });
      return;
    }
    final position = _scrollController.position;
    final canScrollUp = position.pixels > 0;
    final canScrollDown = position.pixels < position.maxScrollExtent;
    
    if (canScrollUp != _canScrollUp || canScrollDown != _canScrollDown) {
      setState(() {
        _canScrollUp = canScrollUp;
        _canScrollDown = canScrollDown;
      });
    }
  }

  void _scrollUp() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final newOffset = (position.pixels - 100).clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _scrollDown() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final newOffset = (position.pixels + 100).clamp(0.0, position.maxScrollExtent);
    _scrollController.animateTo(
      newOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: AppTheme.textSecondary,
        letterSpacing: 1.0,
      );

  String _formatPrice(int price) {
    return LocaleHelper.getCurrencyFormat(widget.countryCode).format(price);
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Toast-style Header for Cart Columns
          Container(
            padding: const EdgeInsets.only(left: 16, right: 64, top: 8, bottom: 8), // Adjusted right padding (48 + 16)
            color: AppTheme.background,
            child: Row(
              children: [
                Expanded(flex: 5, child: Text(AppLocalizations.of(context)!.name, style: _headerStyle)),
                Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.qty, style: _headerStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text(AppLocalizations.of(context)!.price, style: _headerStyle, textAlign: TextAlign.center)),
                Expanded(flex: 3, child: Text(AppLocalizations.of(context)!.total, style: _headerStyle, textAlign: TextAlign.right)),
              ],
            ),
          ),
          const Divider(),

          // 장바구니 아이템 리스트
          Expanded(
            child: cart.isEmpty
                ? _buildEmptyCart(context)
                : Stack(
                    children: [
                      NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          _updateScrollButtons();
                          return false;
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 0, right: 48), // Reduced right padding from 60 to 48
                          itemCount: cart.items.length,
                          separatorBuilder: (_, __) => const Divider(indent: 16, endIndent: 16),
                          itemBuilder: (context, index) {
                            final item = cart.items[index];
                            final isSelected = _selectedItemId == item.product.id;
                            return _CartGridRow(
                              item: item,
                              isSelected: isSelected,
                              onTap: () {
                                setState(() {
                                  _selectedItemId = isSelected ? null : item.product.id;
                                });
                              },
                              onQuantityChanged: (quantity) =>
                                  widget.onQuantityChanged(item.product.id, quantity),
                              onRemove: () {
                                widget.onItemRemove(item.product.id);
                                setState(() {
                                  if (_selectedItemId == item.product.id) {
                                    _selectedItemId = null;
                                  }
                                });
                              },
                              formatPrice: _formatPrice,
                            );
                          },
                        ),
                      ),
                      // Up/Down Scroll Buttons
                      Positioned(
                        right: 4,
                        top: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _ScrollCircleButton(
                              icon: Icons.keyboard_arrow_up,
                              onPressed: _scrollUp,
                              enabled: _canScrollUp,
                            ),
                            const SizedBox(height: 8),
                            _ScrollCircleButton(
                              icon: Icons.keyboard_arrow_down,
                              onPressed: _scrollDown,
                              enabled: _canScrollDown,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),

          // 하단 합계 정보
          _buildSummaryArea(context, cart),
        ],
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.shopping_basket_outlined,
              size: 48,
              color: AppTheme.textSecondary.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.cartEmpty,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryArea(BuildContext context, Cart cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.border, width: 2)),
      ),
      child: Column(
        children: [
          _buildSummaryRow(AppLocalizations.of(context)!.translate('sales.subtotal'), _formatPrice(cart.subtotal)),
          
          // 할인 내역 상세 표시
          ..._buildDiscountBreakdown(cart),
          
          if (cart.totalTax > 0)
            _buildSummaryRow(AppLocalizations.of(context)!.translate('sales.tax'), _formatPrice(cart.totalTax)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  AppLocalizations.of(context)!.totalPayment,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatPrice(cart.total),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDiscountBreakdown(Cart cart) {
    List<Widget> rows = [];
    
    // 1. 개별 상품/카테고리 할인 수집
    final Map<String, int> discountGroups = {};
    for (final item in cart.items) {
      for (final discount in item.appliedDiscounts) {
        final key = '${discount.name} (${discount.type == 'PRODUCT' ? '상품' : '분류'})';
        int amount = 0;
        if (discount.method == 'PERCENTAGE') {
          amount = (item.baseAndOptionsPrice * (discount.rateOrAmount / 100)).round() * item.quantity;
        } else {
          amount = discount.rateOrAmount * item.quantity;
        }
        discountGroups[key] = (discountGroups[key] ?? 0) + amount;
      }
    }
    
    // 2. 장바구니 할인 추가
    for (final discount in cart.cartDiscounts) {
      int amount = 0;
      if (discount.method == 'PERCENTAGE') {
        amount = (cart.subtotal * (discount.rateOrAmount / 100)).round();
      } else {
        amount = discount.rateOrAmount;
      }
      discountGroups[discount.name] = (discountGroups[discount.name] ?? 0) + amount;
    }
    
    if (discountGroups.isEmpty) {
      rows.add(_buildSummaryRow(AppLocalizations.of(context)!.discountAmount, _formatPrice(0)));
    } else {
      discountGroups.forEach((name, amount) {
        rows.add(_buildSummaryRow(
          name, 
          '-${_formatPrice(amount)}', 
          color: AppTheme.error,
          isSmall: true,
        ));
      });
      rows.add(_buildSummaryRow(
        AppLocalizations.of(context)!.translate('sales.totalDiscount') ?? '총 할인', 
        '-${_formatPrice(cart.totalDiscountAmount)}', 
        color: AppTheme.error,
        isLarge: true,
      ));
    }
    
    return rows;
  }

  Widget _buildSummaryRow(String label, String value, {Color? color, bool isLarge = false, bool isSmall = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 2.0 : 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            color: isSmall ? AppTheme.textSecondary.withOpacity(0.7) : AppTheme.textSecondary, 
            fontSize: isLarge ? 14 : (isSmall ? 11 : 12),
          )),
          Text(value, style: TextStyle(
            fontWeight: isLarge ? FontWeight.bold : FontWeight.w500, 
            color: color ?? AppTheme.textPrimary,
            fontSize: isLarge ? 16 : (isSmall ? 12 : 14),
          )),
        ],
      ),
    );
  }
}

class _ScrollCircleButton extends StatelessWidget {
  const _ScrollCircleButton({
    required this.icon,
    required this.onPressed,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? Colors.white : Colors.white.withOpacity(0.5),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, color: enabled ? AppTheme.primary : Colors.grey[300]),
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(36, 36),
        ),
      ),
    );
  }
}

class _CartGridRow extends StatelessWidget {
  const _CartGridRow({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.onQuantityChanged,
    required this.onRemove,
    required this.formatPrice,
  });

  final CartItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onRemove;
  final String Function(int) formatPrice;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? AppTheme.primary.withOpacity(0.05) : Colors.transparent,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.selectedOptions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            item.selectedOptions.map((o) => '+ ${o.name}').join(', '),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ),
                      if (item.discountAmount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '${AppLocalizations.of(context)!.discount}: -${formatPrice(item.discountAmount)}',
                            style: const TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(formatPrice(item.unitPrice), textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    formatPrice(item.finalPrice),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildQtyBtn(Icons.remove, item.quantity > 1 ? () => onQuantityChanged(item.quantity - 1) : null),
                        _buildQtyBtn(Icons.add, () => onQuantityChanged(item.quantity + 1)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(AppLocalizations.of(context)!.translate('common.delete')),
                    style: TextButton.styleFrom(foregroundColor: AppTheme.error, padding: EdgeInsets.zero),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: onTap == null ? Colors.grey[300] : AppTheme.textPrimary),
      ),
    );
  }
}

class _ScrollButton extends StatelessWidget {
  const _ScrollButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled ? AppTheme.surface : AppTheme.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: enabled ? AppTheme.primary : AppTheme.border,
              width: 2,
            ),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 24,
            color: enabled ? AppTheme.primary : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CartGridDiscountFooterRow extends StatelessWidget {
  const _CartGridDiscountFooterRow({
    required this.discount,
    required this.formatPrice,
  });

  final DiscountModel discount;
  final String Function(int) formatPrice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.border.withOpacity(0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          // 할인 태그 및 이름 (왼쪽 정렬)
          Expanded(
            flex: 13, // 5 + 2 + 2 + 2 + 2 = 13 (Price 컬럼 3 제외)
            child: Row(
              children: [
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.discount,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    discount.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                    overflow: TextOverflow.visible, // 이름이 다 보이도록 설정
                  ),
                ),
              ],
            ),
          ),

          // 할인 금액 (오른쪽 끝 정렬, 상품 가격 컬럼에 맞춤)
          Expanded(
            flex: 3, // Final Price 컬럼에 맞춰 flex 3
            child: Padding(
              padding: const EdgeInsets.only(right: 12), // 스크롤바 공간 확보
              child: Text(
                '-${formatPrice(discount.rateOrAmount)}',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.error,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

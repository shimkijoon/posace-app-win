import 'package:flutter/material.dart';
import '../../../core/models/cart.dart';
import '../../../core/models/cart_item.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models.dart';

typedef ValueChanged2<T1, T2> = void Function(T1 value1, T2 value2);

class CartGrid extends StatefulWidget {
  const CartGrid({
    super.key,
    required this.cart,
    required this.onQuantityChanged,
    required this.onItemRemove,
  });

  final Cart cart;
  final ValueChanged2<String, int> onQuantityChanged;
  final ValueChanged<String> onItemRemove;

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

  String _formatPrice(int price) {
    return '₩${price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Column(
        children: [
          // 컬럼 헤더 + 스크롤 버튼
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  border: Border(
                    bottom: BorderSide(color: AppTheme.border, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6, // 상품명
                      child: Text(
                        '상품명',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 2, // 바코드
                      child: Text(
                        '바코드',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 2, // 단가
                      child: Text(
                        '단가',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 3, // 수량 (공간 추가 확보)
                      child: Text(
                        '수량',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 2, // 할인
                      child: Text(
                        '할인',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                    ),
                    Expanded(
                      flex: 4, // 금액 (공간 추가 확보)
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          '금액',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 스크롤 버튼 (스크롤 가능할 때만 표시)
              Builder(
                builder: (context) {
                  final hasScrollableContent = _scrollController.hasClients &&
                      _scrollController.position.maxScrollExtent > 0;
                  if (!hasScrollableContent) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ScrollButton(
                          icon: Icons.keyboard_arrow_up,
                          onTap: _scrollUp,
                          enabled: _canScrollUp,
                        ),
                        const SizedBox(width: 4),
                        _ScrollButton(
                          icon: Icons.keyboard_arrow_down,
                          onTap: _scrollDown,
                          enabled: _canScrollDown,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          // 장바구니 아이템 리스트 (10row)
          Expanded(
            child: cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 48,
                          color: AppTheme.textSecondary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '장바구니가 비어있습니다',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      _updateScrollButtons();
                      return false;
                    },
                    child: Scrollbar(
                      controller: _scrollController,
                      thumbVisibility: true, // 항상 표시
                      trackVisibility: true,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.zero,
                        itemCount: cart.items.length,
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
                  ),
          ),

          // 장바구니 할인 (고정 푸터)
          if (cart.cartDiscounts.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.02),
                border: Border(
                  top: BorderSide(color: AppTheme.border.withOpacity(0.5), width: 1),
                ),
              ),
              child: Column(
                children: cart.cartDiscounts.map((discount) => _CartGridDiscountFooterRow(
                  discount: discount,
                  formatPrice: _formatPrice,
                )).toList(),
              ),
            ),

          // 하단 합계 정보
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              border: Border(
                top: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Column(
              children: [
                // 소계
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '소계',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      _formatPrice(cart.subtotal),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 할인
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '할인',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      '-${_formatPrice(cart.totalDiscountAmount)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 세금 (별도세)
                if (cart.totalTax > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '세금 (별도)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        _formatPrice(cart.totalTax),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // 포함세 정보 (참고용)
                if (cart.totalInclusiveTax > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '부가세 (포함)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      Text(
                        _formatPrice(cart.totalInclusiveTax),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // 총액
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          '총액',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(
                          _formatPrice(cart.total),
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: AppTheme.border.withOpacity(0.5), width: 1),
            ),
          ),
          child: Row(
        children: [
          // 상품명
          Expanded(
            flex: 6,
            child: Row(
              children: [
                // X 버튼 (선택되었을 때만 표시)
                if (isSelected)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                    color: AppTheme.error,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                  )
                else
                  const SizedBox(width: 28),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? AppTheme.primary : null,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.selectedOptions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(
                            item.selectedOptions.map((o) => '+ ${o.name}').join(', '),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 10,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 바코드
          Expanded(
            flex: 2,
            child: Text(
              item.product.barcode ?? '-',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
            ),
          ),

          // 단가
          Expanded(
            flex: 2,
            child: Text(
              formatPrice(item.unitPrice),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),

          // 수량
          Expanded(
            flex: 3,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: item.quantity > 1
                      ? () => onQuantityChanged(item.quantity - 1)
                      : null,
                  icon: const Icon(Icons.remove, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${item.quantity}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => onQuantityChanged(item.quantity + 1),
                  icon: const Icon(Icons.add, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),

          // 할인금액
          Expanded(
            flex: 2,
            child: Text(
              item.discountAmount > 0
                  ? '-${formatPrice(item.discountAmount)}'
                  : '-',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: item.discountAmount > 0
                        ? AppTheme.error
                        : AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

          // 최종 금액 (우측 정렬)
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                formatPrice(item.finalPrice),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
              ),
            ),
          ),
        ],
          ),
        ),
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
                    '할인',
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

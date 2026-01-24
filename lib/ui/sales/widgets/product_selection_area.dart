import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models.dart';

class ProductSelectionArea extends StatefulWidget {
  const ProductSelectionArea({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.products,
    required this.onCategorySelected,
    required this.onProductTap,
  });

  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final List<ProductModel> products;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<ProductModel> onProductTap;

  @override
  State<ProductSelectionArea> createState() => _ProductSelectionAreaState();
}

class _ProductSelectionAreaState extends State<ProductSelectionArea> {
  final ScrollController _categoryScrollController = ScrollController();

  void _scrollCategories(double offset) {
    _categoryScrollController.animateTo(
      _categoryScrollController.offset + offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 카테고리 탭 (고정 + 좌우 스크롤 버튼)
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(
              bottom: BorderSide(color: AppTheme.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              // 왼쪽 스크롤 버튼
              _ScrollIconButton(
                icon: Icons.chevron_left,
                onPressed: () => _scrollCategories(-200),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      _CategoryTab(
                        label: '전체',
                        isSelected: widget.selectedCategoryId == null,
                        onTap: () => widget.onCategorySelected(null),
                      ),
                      const SizedBox(width: 8),
                      ...widget.categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _CategoryTab(
                            label: category.name,
                            isSelected: widget.selectedCategoryId == category.id,
                            onTap: () => widget.onCategorySelected(category.id),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              
              // 오른쪽 스크롤 버튼
              _ScrollIconButton(
                icon: Icons.chevron_right,
                onPressed: () => _scrollCategories(200),
              ),
            ],
          ),
        ),

        // 상품 카드 그리드 (4컬럼 2열 = 8개)
        Expanded(
          child: widget.products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 48,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '상품이 없습니다',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(12),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4컬럼
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 0.9,
                    ),
                    itemCount: widget.products.length > 8 ? 8 : widget.products.length, // 최대 2열 (8개)
                    itemBuilder: (context, index) {
                      return _ProductCard(
                        product: widget.products[index],
                        onTap: () => widget.onProductTap(widget.products[index]),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _ScrollIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ScrollIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: AppTheme.primary, size: 20),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                colors: [AppTheme.primary, AppTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isSelected ? null : AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? Colors.transparent : AppTheme.border,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  final ProductModel product;
  final VoidCallback onTap;

  String _formatPrice(int price) {
    return '₩${price.toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    final isOutOfStock = product.stockEnabled &&
        (product.stockQuantity == null || product.stockQuantity! <= 0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOutOfStock ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppTheme.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 상품 이미지 영역
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(10),
                      topRight: Radius.circular(10),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 32,
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      if (isOutOfStock)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(10),
                              topRight: Radius.circular(10),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '품절',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 상품 정보
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isOutOfStock
                                  ? AppTheme.textSecondary
                                  : AppTheme.textPrimary,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatPrice(product.price),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                              ),
                      ),
                    ],
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

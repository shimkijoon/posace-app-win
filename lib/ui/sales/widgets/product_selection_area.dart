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
        // 카테고리 선택 영역 (Toast-style with Scroll Buttons)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
          ),
          child: Row(
            children: [
              _ScrollIconButton(
                icon: Icons.chevron_left,
                onPressed: () => _scrollCategories(-200),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _categoryScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _CategoryTab(
                        label: '전체',
                        isSelected: widget.selectedCategoryId == null,
                        onTap: () => widget.onCategorySelected(null),
                      ),
                      ...widget.categories.map((category) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
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
              _ScrollIconButton(
                icon: Icons.chevron_right,
                onPressed: () => _scrollCategories(200),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12), // 카테고리와 상품 영역 구분 마진

        // 상품 카드 그리드
        Expanded(
          child: widget.products.isEmpty
              ? _buildEmptyState(context)
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72, // Space for 2-line names and price
                  ),
                  itemCount: widget.products.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(
                      product: widget.products[index],
                      onTap: () => widget.onProductTap(widget.products[index]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textSecondary.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            '등록된 상품이 없습니다',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _ScrollIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _ScrollIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.border),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.textPrimary, size: 20),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        constraints: const BoxConstraints(minWidth: 90),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(color: AppTheme.primary.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
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

    return InkWell(
      onTap: isOutOfStock ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isOutOfStock ? AppTheme.background : AppTheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isOutOfStock ? AppTheme.border : AppTheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 2, // Icon area smaller
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                ),
                child: Center(
                  child: Icon(
                    Icons.fastfood,
                    color: AppTheme.primary.withOpacity(0.1),
                    size: 28,
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              flex: 5, // Text info area larger
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start, // Better for variable line counts
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 32, // Fixed height for 2 lines of text
                      child: Text(
                        product.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatPrice(product.price),
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.primary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    if (product.stockEnabled && !isOutOfStock)
                      Text('${product.stockQuantity} 남아있음', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

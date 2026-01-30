import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/models.dart';

class ProductGrid extends StatelessWidget {
  const ProductGrid({
    super.key,
    required this.products,
    required this.onProductTap,
    this.showBarcodeInGrid = false,
  });

  final List<ProductModel> products;
  final ValueChanged<ProductModel> onProductTap;
  final bool showBarcodeInGrid;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      // ... (existing empty state)
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              '상품이 없습니다',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8, 
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8, 
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          return _ProductCard(
            product: products[index],
            onTap: () => onProductTap(products[index]),
            showBarcode: showBarcodeInGrid,
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.showBarcode,
  });

  final ProductModel product;
  final VoidCallback onTap;
  final bool showBarcode;

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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ... existing image code ...
              // 상품 이미지 영역 (플레이스홀더) - 유통업용으로 더 작게
              Expanded(
                flex: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          size: 36,
                          color: AppTheme.textSecondary.withOpacity(0.3),
                        ),
                      ),
                      if (isOutOfStock)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '품절',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              
              // 상품 정보 영역
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 상품명
                      SizedBox(
                        height: 36, 
                        child: Text(
                          product.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: isOutOfStock
                                    ? AppTheme.textSecondary
                                    : AppTheme.textPrimary,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      // 가격 및 재고
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatPrice(product.price),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: AppTheme.primary,
                                ),
                          ),
                          if (showBarcode && product.barcode != null && product.barcode!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                product.barcode!,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey, // Requested gray tone
                                  // fontFamily: 'monospace', // user said "grey tone", removed monospace for cleaner look unless specified, but kept small size
                                ),
                                overflow: TextOverflow.ellipsis, // Ensure it doesn't break layout
                                maxLines: 1,
                              ),
                            ),
                          if (product.stockEnabled && product.stockQuantity != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '재고: ${product.stockQuantity}개',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: product.stockQuantity! > 10
                                      ? AppTheme.success
                                      : AppTheme.warning,
                                ),
                              ),
                            ),
                        ],
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

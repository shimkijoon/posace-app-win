import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ProductSearchBar extends StatelessWidget {
  const ProductSearchBar({
    super.key,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onBarcodeSubmitted,
  });

  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onBarcodeSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // 검색 아이콘
          Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          
          // 검색 입력 필드
          Expanded(
            child: TextField(
              controller: TextEditingController(text: searchQuery)
                ..selection = TextSelection.collapsed(offset: searchQuery.length),
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: '상품명 또는 바코드 검색',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  onBarcodeSubmitted(value.trim());
                }
              },
            ),
          ),
          
          // 바코드 아이콘
          IconButton(
            onPressed: () {
              // 바코드 스캐너 열기 (나중에 구현)
            },
            icon: Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            tooltip: '바코드 스캔',
          ),
        ],
      ),
    );
  }
}

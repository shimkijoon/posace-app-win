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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: TextEditingController(text: searchQuery)
                        ..selection = TextSelection.collapsed(offset: searchQuery.length),
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: '상품명 또는 바코드를 입력하세요',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        fillColor: Colors.transparent,
                        contentPadding: EdgeInsets.zero,
                        hintStyle: TextStyle(
                          color: Color(0xFFADB5BD),
                          fontSize: 14,
                        ),
                      ),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          onBarcodeSubmitted(value.trim());
                        }
                      },
                    ),
                  ),
                  if (searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => onSearchChanged(''),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _buildActionButton(Icons.qr_code_scanner, '바코드 스캔', () {}),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
        tooltip: tooltip,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      ),
    );
  }
}

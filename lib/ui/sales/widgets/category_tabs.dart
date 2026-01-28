import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/local/models.dart';

class CategoryTabs extends StatelessWidget {
  const CategoryTabs({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  final List<CategoryModel> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategorySelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            // 전체 카테고리 버튼
            _CategoryTab(
              label: AppLocalizations.of(context)!.all,
              isSelected: selectedCategoryId == null,
              onTap: () => onCategorySelected(null),
            ),
            const SizedBox(width: 12),
            
            // 카테고리 버튼들
            ...categories.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CategoryTab(
                  label: category.name,
                  isSelected: selectedCategoryId == category.id,
                  onTap: () => onCategorySelected(category.id),
                ),
              );
            }),
          ],
        ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppTheme.primary.withOpacity(0.2)
                    : Colors.black.withOpacity(0.03),
                blurRadius: isSelected ? 6 : 4,
                offset: Offset(0, isSelected ? 3 : 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                ),
          ),
        ),
      ),
    );
  }
}

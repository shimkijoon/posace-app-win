import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../data/local/models.dart';

class DiscountSelectionDialog extends StatelessWidget {
  const DiscountSelectionDialog({
    super.key,
    required this.availableDiscounts,
    this.selectedDiscountIds = const {},
  });

  final List<DiscountModel> availableDiscounts;
  final Set<String> selectedDiscountIds;

  @override
  Widget build(BuildContext context) {
    final cartDiscounts = availableDiscounts.where((d) => d.type == 'CART').toList();
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 450,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.discount_outlined, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Text(
                  '장바구니 할인 선택',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (cartDiscounts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(AppLocalizations.of(context)!.translate('sales.noCartDiscounts'), style: const TextStyle(color: Colors.grey)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: cartDiscounts.length,
                  itemBuilder: (context, index) {
                    final d = cartDiscounts[index];
                    final isSelected = selectedDiscountIds.contains(d.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primary.withOpacity(0.05) : AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          // TODO: Support multi-select or single select? 
                          // The instruction says "Discount, Hold, Member 진행하자"
                          // Usually manual is single select per cart. 
                          // I'll return the toggled set.
                          final newSet = Set<String>.from(selectedDiscountIds);
                          if (isSelected) {
                            newSet.remove(d.id);
                          } else {
                            newSet.add(d.id);
                          }
                          Navigator.pop(context, newSet);
                        },
                        title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(d.method == 'PERCENTAGE'
                          ? '${d.rateOrAmount}% 할인'
                          : currencyFormat.format(d.rateOrAmount)),
                        trailing: Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected ? AppTheme.primary : Colors.grey,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, <String>{}), // Clear all
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppTheme.error),
                      foregroundColor: AppTheme.error,
                    ),
                    child: Text(AppLocalizations.of(context)!.translate('sales.removeAllDiscounts')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

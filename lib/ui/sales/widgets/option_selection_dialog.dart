import 'package:flutter/material.dart';
import '../../../data/local/models.dart';
import '../../../data/local/models/options_models.dart';
import '../../../core/theme/app_theme.dart';

class OptionSelectionDialog extends StatefulWidget {
  final ProductModel product;

  const OptionSelectionDialog({
    super.key,
    required this.product,
  });

  @override
  State<OptionSelectionDialog> createState() => _OptionSelectionDialogState();
}

class _OptionSelectionDialogState extends State<OptionSelectionDialog> {
  final Map<String, List<ProductOptionModel>> _selectedOptions = {};

  @override
  void initState() {
    super.initState();
    // 초기화 - 비어있음 (필수 체크 로직에서 걸러질 것)
  }

  bool get _canSubmit {
    for (final group in widget.product.optionGroups) {
      if (group.isRequired) {
        final selected = _selectedOptions[group.id] ?? [];
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  double get _totalAdjustment {
    double total = 0;
    _selectedOptions.forEach((_, options) {
      for (final option in options) {
        total += option.priceAdjustment;
      }
    });
    return total;
  }

  void _onOptionToggle(ProductOptionGroupModel group, ProductOptionModel option) {
    setState(() {
      final selected = _selectedOptions[group.id] ?? [];
      
      if (group.isMultiSelect) {
        if (selected.contains(option)) {
          selected.remove(option);
        } else {
          selected.add(option);
        }
      } else {
        // 단일 선택의 경우 기존 것 제거하고 새로 추가
        selected.clear();
        selected.add(option);
      }
      
      _selectedOptions[group.id] = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.product.price + _totalAdjustment;

    return AlertDialog(
      title: Text('${widget.product.name} 옵션 선택'),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...widget.product.optionGroups.map((group) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (group.isRequired)
                            const Text(
                              '(필수)',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          if (group.isMultiSelect)
                            const Text(
                              '(다중선택)',
                              style: TextStyle(color: Colors.blue, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: group.options.map((option) {
                          final isSelected = _selectedOptions[group.id]?.contains(option) ?? false;
                          return ChoiceChip(
                            label: Text(
                              option.name + (option.priceAdjustment != 0 ? ' (+${option.priceAdjustment.round()})' : ''),
                            ),
                            selected: isSelected,
                            onSelected: (_) => _onOptionToggle(group, option),
                            selectedColor: AppTheme.primary.withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? AppTheme.primary : Colors.black,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),
              if (widget.product.bundleItems.isNotEmpty) ...[
                const Text(
                  '세트 구성품',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                ...widget.product.bundleItems.map((item) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, size: 20),
                    title: Text('${item.componentProduct?.name ?? "상품"} x ${item.quantity}'),
                    trailing: item.priceAdjustment != 0
                        ? Text('+${item.priceAdjustment.round()}원')
                        : null,
                  );
                }),
                const SizedBox(height: 16),
              ],
              const Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('합계', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      '${totalPrice.round()}원',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _canSubmit
              ? () {
                  final flatOptions = _selectedOptions.values.expand((element) => element).toList();
                  Navigator.pop(context, flatOptions);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('장바구니 담기'),
        ),
      ],
    );
  }
}

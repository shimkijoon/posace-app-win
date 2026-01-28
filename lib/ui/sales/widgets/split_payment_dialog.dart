import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/local/models/payment_model.dart';
import '../../widgets/virtual_keypad.dart';

class SplitPaymentDialog extends StatefulWidget {
  const SplitPaymentDialog({
    super.key,
    required this.totalAmount,
    this.initialMemberPoints = 0,
  });

  final int totalAmount;
  final int initialMemberPoints;

  @override
  State<SplitPaymentDialog> createState() => _SplitPaymentDialogState();
}

class _SplitPaymentDialogState extends State<SplitPaymentDialog> {
  final List<SalePaymentModel> _payments = [];
  int _remainingAmount = 0;

  @override
  void initState() {
    super.initState();
    _remainingAmount = widget.totalAmount;
  }

  void _addPayment(String method, int amount) {
    if (amount <= 0) return;
    
    setState(() {
      _payments.add(SalePaymentModel(
        id: const Uuid().v4(),
        saleId: '', // Will be set by service
        method: method,
        amount: amount,
      ));
      _remainingAmount -= amount;
    });
  }

  void _removePayment(int index) {
    setState(() {
      _remainingAmount += _payments[index].amount;
      _payments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context)!.translate('payment.splitPayment')),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Summary Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(AppLocalizations.of(context)!.translate('payment.totalPaymentAmount'), widget.totalAmount, isTotal: true),
                  const Divider(),
                  _buildSummaryRow(AppLocalizations.of(context)!.translate('payment.paidAmount'), widget.totalAmount - _remainingAmount),
                  _buildSummaryRow(AppLocalizations.of(context)!.translate('payment.remainingAmount'), _remainingAmount, highlight: _remainingAmount > 0),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Payments List
            if (_payments.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(AppLocalizations.of(context)!.translate('payment.paymentHistory'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _payments.length,
                  itemBuilder: (context, index) {
                    final p = _payments[index];
                    return ListTile(
                      dense: true,
                      title: Text('${p.method} ${AppLocalizations.of(context)!.translate('payment.payment')}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${p.amount}${AppLocalizations.of(context)!.translate('session.won')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                            onPressed: () => _removePayment(index),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
            ],

            const SizedBox(height: 10),
            
            // Payment Actions
            if (_remainingAmount > 0) ...[
              Text(AppLocalizations.of(context)!.translate('payment.selectPaymentMethod')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildPaymentButton(
                      AppLocalizations.of(context)!.translate('payment.cashFull'),
                      Icons.money,
                      Colors.green,
                      () => _addPayment('CASH', _remainingAmount),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildPaymentButton(
                      AppLocalizations.of(context)!.translate('payment.cardFull'),
                      Icons.credit_card,
                      Colors.blue,
                      () => _addPayment('CARD', _remainingAmount),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showManualAmountDialog('CASH'),
                      child: Text(AppLocalizations.of(context)!.translate('payment.cashManual')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showManualAmountDialog('CARD'),
                      child: Text(AppLocalizations.of(context)!.translate('payment.cardManual')),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
        ),
        ElevatedButton(
          onPressed: _remainingAmount == 0 ? () => Navigator.pop(context, _payments) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(AppLocalizations.of(context)!.translate('payment.paymentComplete')),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, int amount, {bool isTotal = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          )),
          Text(
            '$amount${AppLocalizations.of(context)!.translate('session.won')}',
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.red : (isTotal ? AppTheme.primary : null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  Future<void> _showManualAmountDialog(String method) async {
    String currentInput = _remainingAmount.toString();
    
    final amount = await showDialog<int?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('$method ${AppLocalizations.of(context)!.translate('payment.amountInput')}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$currentInput${AppLocalizations.of(context)!.translate('session.won')}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: 300,
                  child: VirtualKeypad(
                    onKeyPress: (key) {
                      setState(() {
                         if (currentInput == '0') {
                           currentInput = key;
                         } else {
                           currentInput += key;
                         }
                      });
                    },
                    onDelete: () {
                      setState(() {
                        if (currentInput.isNotEmpty) {
                          currentInput = currentInput.substring(0, currentInput.length - 1);
                          if (currentInput.isEmpty) currentInput = '0';
                        }
                      });
                    },
                    onClear: () {
                      setState(() => currentInput = '0');
                    },
                    onEnter: () {
                      Navigator.pop(context, int.tryParse(currentInput));
                    },
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );

    if (amount != null && amount > 0) {
      if (amount > _remainingAmount) {
         // Optionally handle overpayment/change
         _addPayment(method, _remainingAmount);
      } else {
         _addPayment(method, amount);
      }
    }
  }
}

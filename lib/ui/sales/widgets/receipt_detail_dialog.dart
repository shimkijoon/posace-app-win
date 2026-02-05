import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/models.dart';
import '../../../core/printer/printer_manager.dart';
import '../../../core/printer/receipt_templates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/settings_storage.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/i18n/locale_helper.dart';

class ReceiptDetailDialog extends StatefulWidget {
  const ReceiptDetailDialog({
    super.key,
    required this.sale,
    required this.database,
  });

  final SaleModel sale;
  final AppDatabase database;

  @override
  State<ReceiptDetailDialog> createState() => _ReceiptDetailDialogState();
}

class _ReceiptDetailDialogState extends State<ReceiptDetailDialog> {
  List<SaleItemModel> _items = [];
  Map<String, ProductModel> _productMap = {};
  bool _isLoading = true;

  Map<String, dynamic> _storeInfo = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final items = await widget.database.getSaleItems(widget.sale.id);
    final products = await widget.database.getProducts();
    final productMap = {for (var p in products) p.id: p};
    
    final auth = AuthStorage();
    final storeInfo = await auth.getSessionInfo();
    
    if (mounted) {
      setState(() {
        _items = items;
        _productMap = productMap;
        _storeInfo = storeInfo;
        _isLoading = false;
      });
    }
  }

  Future<void> _reprint() async {
    print('ReceiptDetailDialog: Requesting reprint for sale ${widget.sale.id}');
    final printerManager = PrinterManager();

    final bytes = widget.sale.status == 'CANCELLED'
        ? await ReceiptTemplates.cancelReceipt(widget.sale, _items, _productMap, storeInfo: _storeInfo)
        : await ReceiptTemplates.saleReceipt(widget.sale, _items, _productMap, storeInfo: _storeInfo, context: context);
    
    final success = await printerManager.printReceipt(bytes);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 인쇄에 실패했습니다. 설정을 확인해 주세요.')),
      );
    }
  }

  String _localizePaymentMethod(String method) {
    switch (method.toUpperCase()) {
      case 'CARD': return '카드';
      case 'CASH': return '현금';
      default: return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final sessionCountry = (_storeInfo['country'] as String?)?.trim();
    final uiLanguage = (_storeInfo['uiLanguage'] as String?)?.trim() ?? '';
    final derivedCountry = () {
      if (uiLanguage.startsWith('ja')) return 'JP';
      if (uiLanguage == 'zh-TW') return 'TW';
      if (uiLanguage == 'zh-HK') return 'HK';
      if (uiLanguage == 'en-SG') return 'SG';
      if (uiLanguage == 'en-AU') return 'AU';
      return 'KR';
    }();
    final countryCode =
        (sessionCountry != null && sessionCountry.isNotEmpty) ? sessionCountry : derivedCountry;
    final currencyFormat = LocaleHelper.getCurrencyFormat(countryCode);
    final storeName = _storeInfo['name'] ?? 'POSAce Store';
    final bizNo = _storeInfo['businessNumber'] ?? '-';
    final address = _storeInfo['address']?.replaceAll('||', ' ') ?? '-';
    final phone = _storeInfo['phone'] ?? '-';

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      '영수증 상세',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),
              
              // Digital Receipt Area
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9F9F7), // Thermal paper hint
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(storeName, 
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('사업자 번호: $bizNo', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                        Text('주소: $address', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                        Text('전화: $phone', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
                        const SizedBox(height: 16),
                        _buildReceiptText('일시', DateFormat('yyyy-MM-dd (E) HH:mm:ss', 'ko_KR').format(widget.sale.createdAt)),
                        _buildReceiptText('거래번호', widget.sale.id.substring(0, 8).toUpperCase()),
                        _buildReceiptText('상태', widget.sale.status == 'CANCELLED' ? '결제취소' : '정상결제', 
                          valueColor: widget.sale.status == 'CANCELLED' ? AppTheme.error : AppTheme.success),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('------------------------------------------', 
                            style: TextStyle(color: Colors.grey, letterSpacing: 1), textAlign: TextAlign.center),
                        ),
                        
                        // Header for items
                        DefaultTextStyle(
                          style: const TextStyle(fontFamily: 'monospace', color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold),
                          child: Row(
                            children: [
                              Expanded(flex: 20, child: Text(AppLocalizations.of(context)!.translate('sales.productName'))),
                              Expanded(flex: 6, child: Text(AppLocalizations.of(context)!.translate('sales.qty'), textAlign: TextAlign.right)),
                              Expanded(flex: 16, child: Text(AppLocalizations.of(context)!.translate('sales.amount'), textAlign: TextAlign.right)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('------------------------------------------', 
                            style: TextStyle(color: Colors.grey, letterSpacing: 1), textAlign: TextAlign.center),
                        const SizedBox(height: 8),

                        ..._items.map((item) {
                          final product = _productMap[item.productId];
                          final name = product?.name ?? 'Unknown';
                          final qtyStr = item.qty.toString();
                          final priceStr = currencyFormat.format(item.price * item.qty);

                          List<Widget> itemRows = [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: DefaultTextStyle(
                                style: const TextStyle(fontFamily: 'monospace', color: Colors.black, fontSize: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 20, child: Text(name, overflow: TextOverflow.visible)),
                                    Expanded(flex: 6, child: Text(qtyStr, textAlign: TextAlign.right)),
                                    Expanded(flex: 16, child: Text(priceStr, textAlign: TextAlign.right)),
                                  ],
                                ),
                              ),
                            )
                          ];

                          if (item.discountsJson != null && item.discountsJson!.isNotEmpty) {
                            try {
                              final List<dynamic> itemDiscounts = jsonDecode(item.discountsJson!);
                              for (var d in itemDiscounts) {
                                final dName = d['name'] ?? '할인';
                                final dAmount = d['amount'] ?? 0;
                                if (dAmount > 0) {
                                  itemRows.add(
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0, bottom: 2.0),
                                      child: DefaultTextStyle(
                                        style: const TextStyle(fontFamily: 'monospace', color: AppTheme.error, fontSize: 11),
                                        child: Row(
                                          children: [
                                            Expanded(flex: 26, child: Text('  [할인] $dName')),
                                            Expanded(flex: 16, child: Text('-${currencyFormat.format(dAmount)}', textAlign: TextAlign.right)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            } catch (_) {}
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: itemRows,
                          );
                        }),
                        
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('------------------------------------------', 
                            style: TextStyle(color: Colors.grey, letterSpacing: 1), textAlign: TextAlign.center),
                        ),
                        
                        _buildReceiptText(AppLocalizations.of(context)!.translate('sales.subtotal'), currencyFormat.format(widget.sale.totalAmount + widget.sale.discountAmount)),
                        
                        if (widget.sale.discountAmount > 0) ...[
                           if (widget.sale.cartDiscountsJson != null) ...(() {
                             try {
                               final List<dynamic> cartDiscounts = jsonDecode(widget.sale.cartDiscountsJson!);
                               return cartDiscounts.map((d) {
                                 final dName = d['name'] ?? '할인';
                                 final dAmount = d['amount'] ?? 0;
                                 return _buildReceiptText('  $dName', '-${currencyFormat.format(dAmount)}', valueColor: AppTheme.error);
                               }).toList();
                             } catch (_) { return <Widget>[]; }
                           })(),
                           _buildReceiptText(AppLocalizations.of(context)!.translate('sales.totalDiscount'), '-${currencyFormat.format(widget.sale.discountAmount)}', 
                             valueColor: AppTheme.error, isBold: true),
                        ],

                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppLocalizations.of(context)!.totalPayment, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(currencyFormat.format(widget.sale.totalAmount), 
                              style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 18, 
                                color: widget.sale.status == 'CANCELLED' ? AppTheme.error : AppTheme.primary,
                                fontFamily: 'monospace'
                              )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildReceiptText('결제수단', _localizePaymentMethod(widget.sale.paymentMethod ?? 'CASH')),
                        const SizedBox(height: 16),
                        Text('이용해 주셔서 감사합니다', 
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _reprint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.print, size: 18),
                            label: Text(AppLocalizations.of(context)!.translate('receiptDialog.reprint'), style: const TextStyle(fontWeight: FontWeight.bold, inherit: false)),
                          ),
                        ),
                      ],
                    ),
                    if (widget.sale.status != 'CANCELLED') ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _cancelOrder,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.error,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: AppTheme.error.withOpacity(0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, size: 18),
                              label: Text(AppLocalizations.of(context)!.translate('receiptDialog.cancelPayment'), style: const TextStyle(fontWeight: FontWeight.bold, inherit: false)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptText(String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: isBold ? FontWeight.bold : null)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: valueColor, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('receiptDialog.cancelPayment')),
        content: Text(AppLocalizations.of(context)!.translate('receiptDialog.cancelConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.translate('common.no'))),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: Text(AppLocalizations.of(context)!.translate('common.yes'))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = await widget.database.database;
      await db.update(
        'sales',
        {'status': 'CANCELLED', 'syncedAt': null}, // Reset syncedAt to re-push cancellation
        where: 'id = ?',
        whereArgs: [widget.sale.id],
      );

      // Print Cancellation Receipt
      final printerManager = PrinterManager();
      final bytes = await ReceiptTemplates.cancelReceipt(widget.sale, _items, _productMap, storeInfo: _storeInfo);
      await printerManager.printReceipt(bytes);

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate change
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문이 취소되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('취소 처리 중 오류 발생: $e')));
      }
    }
  }
}

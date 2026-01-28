import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../data/local/models.dart';
import '../i18n/app_localizations.dart';
import '../storage/auth_storage.dart';
import 'esc_pos_encoder.dart';

class ReceiptTemplates {
  static final _currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
  static final _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  static int _getDisplayWidth(String text) {
    int width = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code > 128) {
        width += 2; // Korean
      } else {
        width += 1; // ASCII
      }
    }
    return width;
  }

  static String _padRight(String text, int width) {
    int currentWidth = _getDisplayWidth(text);
    if (currentWidth >= width) return text;
    return text + ' ' * (width - currentWidth);
  }

  static String _padLeft(String text, int width) {
    int currentWidth = _getDisplayWidth(text);
    if (currentWidth >= width) return text;
    return ' ' * (width - currentWidth) + text;
  }

  static Future<Uint8List> saleReceipt(SaleModel sale, List<SaleItemModel> items, Map<String, ProductModel> productMap, {Map<String, String?> storeInfo = const {}, BuildContext? context}) async {
    print('ReceiptTemplates: Generating sale receipt for sale ${sale.id}');
    final storeName = storeInfo['name'] ?? 'POSAce Store';
    final bizNo = storeInfo['businessNumber'] ?? '-';
    final address = storeInfo['address']?.replaceAll('||', ' ') ?? '-';
    final phone = storeInfo['phone'] ?? '-';

    // Get translations if context is available
    String businessNumberLabel = '사업자번호';
    String addressLabel = '주소';
    String phoneLabel = '전화';
    String dateTimeLabel = '일시';
    String transactionLabel = '거래 NO';
    String productNameLabel = '상품명';
    String qtyLabel = '수량';
    String amountLabel = '금액';
    String discountLabel = '할인';
    String subtotalLabel = '소계';
    String totalLabel = '합계';
    String paymentMethodLabel = '결제수단';
    String changeLabel = '거스름돈';
    String thankYouMessage = '이용해 주셔서 감사합니다';
    
    if (context != null) {
      final localizations = AppLocalizations.of(context);
      if (localizations != null) {
        businessNumberLabel = localizations.businessNumber;
        addressLabel = localizations.address;
        phoneLabel = localizations.phone;
        dateTimeLabel = localizations.translate('receipt.dateTime');
        transactionLabel = localizations.translate('receipt.transactionNumber');
        productNameLabel = localizations.translate('sales.productName');
        qtyLabel = localizations.translate('sales.qty');
        amountLabel = localizations.translate('receipt.amount');
        discountLabel = localizations.discount;
        subtotalLabel = localizations.subtotal;
        totalLabel = localizations.translate('sales.total');
        paymentMethodLabel = localizations.translate('receipt.paymentMethod');
        changeLabel = localizations.translate('receipt.change');
        thankYouMessage = localizations.translate('receipt.thankYouMessage');
      }
    }
    
    final encoder = EscPosEncoder();
    encoder.reset();
    
    // Header
    encoder.setAlign('center');
    await encoder.text(storeName, bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(1);
    encoder.setAlign('center');
    await encoder.text('$businessNumberLabel: $bizNo');
    encoder.lineFeed();
    await encoder.text('$addressLabel: $address');
    encoder.lineFeed();
    await encoder.text('$phoneLabel: $phone');
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('$dateTimeLabel: ${_dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.text('$transactionLabel: ${sale.id.substring(0, 8)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    // Items Header (Name: 20, Qty: 6, Amt: 16 -> Total 42)
    String header = _padRight(productNameLabel, 20) + _padLeft(qtyLabel, 6) + _padLeft(amountLabel, 16);
    await encoder.text(header);
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      final qtyStr = item.qty.toString();
      final priceStr = _currencyFormat.format(item.price * item.qty);

      int nameWidth = _getDisplayWidth(name);
      
      if (nameWidth <= 20) {
        // Name, Qty, Price on one line
        String line = _padRight(name, 20) + _padLeft(qtyStr, 6) + _padLeft(priceStr, 16);
        await encoder.text(line);
        encoder.lineFeed();
      } else {
        // Name on first line, Qty/Price on second line
        await encoder.text(name);
        encoder.lineFeed();
        String line = _padLeft(qtyStr, 26) + _padLeft(priceStr, 16);
        await encoder.text(line);
        encoder.lineFeed();
      }

      // Discount lines for the item
      if (item.discountsJson != null && item.discountsJson!.isNotEmpty) {
        try {
          final List<dynamic> itemDiscounts = jsonDecode(item.discountsJson!);
          for (var d in itemDiscounts) {
            final dName = d['name'] ?? discountLabel;
            final dAmount = d['amount'] ?? 0;
            if (dAmount > 0) {
              String dLine = _padRight('  [$discountLabel] $dName', 26) + _padLeft('-${_currencyFormat.format(dAmount)}', 16);
              await encoder.text(dLine);
              encoder.lineFeed();
            }
          }
        } catch (e) {
          print('Error parsing item discounts: $e');
        }
      }
    }
    
    await encoder.dashLine();
    
    // Totals
    encoder.setStyles(bold: true);
    
    // Subtotal
    int subtotal = sale.totalAmount + sale.discountAmount;
    String subtotalVal = _currencyFormat.format(subtotal);
    String subtotalLine = _padRight('$subtotalLabel:', 42 - _getDisplayWidth(subtotalVal)) + subtotalVal;
    await encoder.text(subtotalLine);
    encoder.lineFeed();

    // Discounts in Footer
    if (sale.discountAmount > 0) {
      encoder.setStyles(bold: false);
      
      // Cart level discounts
      if (sale.cartDiscountsJson != null) {
        try {
          final List<dynamic> cartDiscounts = jsonDecode(sale.cartDiscountsJson!);
          for (var d in cartDiscounts) {
             final dName = d['name'] ?? discountLabel;
             final dAmount = d['amount'] ?? 0;
             if (dAmount > 0) {
               String dVal = '-${_currencyFormat.format(dAmount)}';
               String dLine = _padRight('  $dName:', 42 - _getDisplayWidth(dVal)) + dVal;
               await encoder.text(dLine);
               encoder.lineFeed();
             }
          }
        } catch (_) {}
      }

      // Total Discount
      String discVal = '-${_currencyFormat.format(sale.discountAmount)}';
      String discLine = _padRight('${discountLabel}:', 42 - _getDisplayWidth(discVal)) + discVal;
      await encoder.text(discLine);
      encoder.lineFeed();
    }

    encoder.setStyles(bold: true);
    String totalLabelText = '$totalLabel:';
    String totalVal = _currencyFormat.format(sale.totalAmount);
    String totalLine = _padRight(totalLabelText, 42 - _getDisplayWidth(totalVal)) + totalVal;
    await encoder.text(totalLine);
    encoder.lineFeed(2);
    
    // Payment
    encoder.setStyles(bold: false);
    await encoder.text('$paymentMethodLabel: ${sale.paymentMethod}');
    encoder.lineFeed(2);
    
    encoder.cut();
    return encoder.bytes;
  }

  static Future<Uint8List> cancelReceipt(SaleModel sale, List<SaleItemModel> items, Map<String, ProductModel> productMap, {Map<String, String?> storeInfo = const {}}) async {
    print('ReceiptTemplates: Generating cancel receipt for sale ${sale.id}');
    final storeName = storeInfo['name'] ?? 'POSAce Store';
    final bizNo = storeInfo['businessNumber'] ?? '-';

    final encoder = EscPosEncoder();
    encoder.reset();
    
    // Header
    encoder.setAlign('center');
    await encoder.text('*** [취 소] ***', bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(1);
    await encoder.text(storeName, bold: true);
    encoder.lineFeed(1);
    await encoder.text('사업자번호: $bizNo');
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('취소일시: ${_dateFormat.format(DateTime.now())}');
    encoder.lineFeed();
    await encoder.text('원거래일: ${_dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.text('거래 NO: ${sale.id.substring(0, 8)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      final qtyStr = (-item.qty).toString();
      final priceStr = _currencyFormat.format(-(item.price * item.qty));

      int nameWidth = _getDisplayWidth(name);
      if (nameWidth <= 20) {
        String line = _padRight(name, 20) + _padLeft(qtyStr, 6) + _padLeft(priceStr, 16);
        await encoder.text(line);
        encoder.lineFeed();
      } else {
        await encoder.text(name);
        encoder.lineFeed();
        String line = _padLeft(qtyStr, 26) + _padLeft(priceStr, 16);
        await encoder.text(line);
        encoder.lineFeed();
      }

      // Discount lines for the item
      if (item.discountsJson != null && item.discountsJson!.isNotEmpty) {
        try {
          final List<dynamic> itemDiscounts = jsonDecode(item.discountsJson!);
          for (var d in itemDiscounts) {
            final dName = d['name'] ?? '할인';
            final dAmount = d['amount'] ?? 0;
            if (dAmount > 0) {
              String dLine = _padRight('  [할인] $dName', 26) + _padLeft('+${_currencyFormat.format(dAmount)}', 16);
              await encoder.text(dLine);
              encoder.lineFeed();
            }
          }
        } catch (_) {}
      }
    }
    
    await encoder.dashLine();
    
    // Totals
    encoder.setStyles(bold: true);
    
    // Subtotal
    int subtotal = sale.totalAmount + sale.discountAmount;
    String subtotalVal = _currencyFormat.format(-subtotal);
    String subtotalLine = _padRight('취소 소계:', 42 - _getDisplayWidth(subtotalVal)) + subtotalVal;
    await encoder.text(subtotalLine);
    encoder.lineFeed();

    // Discount reversal
    if (sale.discountAmount > 0) {
      encoder.setStyles(bold: false);
      String discVal = '+${_currencyFormat.format(sale.discountAmount)}';
      String discLine = _padRight('  할인 취소액:', 42 - _getDisplayWidth(discVal)) + discVal;
      await encoder.text(discLine);
      encoder.lineFeed();
    }

    encoder.setStyles(bold: true);
    String totalLabel = '취소 확정액:';
    String totalVal = _currencyFormat.format(-sale.totalAmount);
    String totalLine = _padRight(totalLabel, 42 - _getDisplayWidth(totalVal)) + totalVal;
    await encoder.text(totalLine);
    encoder.lineFeed(2);
    
    encoder.cut();
    return encoder.bytes;
  }

  static Future<Uint8List> kitchenOrder(SaleModel sale, List<SaleItemModel> items, Map<String, ProductModel> productMap) async {
    print('ReceiptTemplates: Generating kitchen order for sale ${sale.id}');
    final encoder = EscPosEncoder();
    encoder.reset();
    
    encoder.setAlign('center');
    await encoder.text('*** 주방주문서 ***', bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('주문일시: ${_dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      // Kitchen orders usually use large fonts, so we keep name and qty on separate lines if needed
      // or just name on one line, qty on next line as it was.
      await encoder.text(name, doubleHeight: true, doubleWidth: true);
      encoder.lineFeed();
      await encoder.text('    수량: ${item.qty}', doubleHeight: true, doubleWidth: true);
      encoder.lineFeed();
    }
    
    await encoder.dashLine();
    encoder.cut();
    return encoder.bytes;
  }
}

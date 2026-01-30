import 'dart:typed_data';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../data/local/models.dart';
import '../i18n/app_localizations.dart';
import '../i18n/locale_helper.dart';
import '../storage/auth_storage.dart';
import 'esc_pos_encoder.dart';

class ReceiptTemplates {
  // 번역 헬퍼: 번역 실패 시 fallback 사용
  static String _translate(AppLocalizations? localizations, String key, String fallback) {
    if (localizations == null) return fallback;
    final result = localizations.translate(key);
    // 번역 실패 시 키가 그대로 반환되므로 fallback 사용
    return (result == key) ? fallback : result;
  }

  static int _getDisplayWidth(String text) {
    int width = 0;
    for (int i = 0; i < text.length; i++) {
      int code = text.codeUnitAt(i);
      if (code > 128) {
        width += 2; 
      } else {
        width += 1; 
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

  static Future<Uint8List> saleReceipt(
    SaleModel sale, 
    List<SaleItemModel> items, 
    Map<String, ProductModel> productMap, 
    {Map<String, dynamic> storeInfo = const {}, 
    StoreSettingsModel? settings,
    BuildContext? context}
  ) async {
    print('ReceiptTemplates: Generating sale receipt for sale ${sale.id}');
    
    final country = settings?.receiptTemplate?.country ?? 'KR';
    final currencyFormat = LocaleHelper.getCurrencyFormat(country);
    final dateFormat = LocaleHelper.getDateFormat(country);
    
    final storeName = storeInfo['name'] ?? 'POSAce Store';
    final bizNo = storeInfo['businessNumber'] ?? '-';
    final address = storeInfo['address']?.replaceAll('||', ' ') ?? '-';
    final phone = storeInfo['phone'] ?? '-';

    final localizations = context != null ? AppLocalizations.of(context) : null;
    
    final encoder = EscPosEncoder();
    encoder.reset();
    
    // Header
    encoder.setAlign('center');
    await encoder.text(storeName, bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(1);
    
    if (settings?.receiptHeader != null && settings!.receiptHeader!.isNotEmpty) {
      await encoder.text(settings.receiptHeader!);
      encoder.lineFeed(1);
    }

    encoder.setAlign('center');
    await encoder.text('${localizations?.businessNumber ?? '사업자번호'}: $bizNo');
    encoder.lineFeed();
    await encoder.text('${localizations?.address ?? '주소'}: $address');
    encoder.lineFeed();
    await encoder.text('${localizations?.phone ?? '전화'}: $phone');
    
    // Country specific header fields
    if (country == 'AU' && storeInfo['abn'] != null) {
      await encoder.text('ABN: ${storeInfo['abn']}');
      encoder.lineFeed();
    } else if (country == 'SG' && storeInfo['gstNumber'] != null) {
      await encoder.text('GST Reg No: ${storeInfo['gstNumber']}');
      encoder.lineFeed();
    }
    
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('${_translate(localizations, 'receipt.dateTime', '일시')}: ${dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.text('${_translate(localizations, 'receipt.transactionNumber', '거래 NO')}: ${sale.id.substring(0, 8)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    // Items Header
    String productNameLabel = _translate(localizations, 'sales.productName', '상품명');
    String qtyLabel = _translate(localizations, 'sales.qty', '수량');
    String amountLabel = _translate(localizations, 'receipt.amount', '금액');
    
    String header = _padRight(productNameLabel, 20) + _padLeft(qtyLabel, 6) + _padLeft(amountLabel, 16);
    await encoder.text(header);
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      final qtyStr = item.qty.toString();
      final priceStr = currencyFormat.format(item.price * item.qty);

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

      // Item discounts
      if (settings?.receiptShowDiscountDetails != false && item.discountsJson != null && item.discountsJson!.isNotEmpty) {
        try {
          final List<dynamic> itemDiscounts = jsonDecode(item.discountsJson!);
          for (var d in itemDiscounts) {
            final dName = d['name'] ?? 'Discount';
            final dAmount = d['amount'] ?? 0;
            if (dAmount > 0) {
              String dLine = _padRight('  [-] $dName', 26) + _padLeft('-${currencyFormat.format(dAmount)}', 16);
              await encoder.text(dLine);
              encoder.lineFeed();
            }
          }
        } catch (_) {}
      }
    }
    
    await encoder.dashLine();
    
    // Summary
    encoder.setStyles(bold: true);
    
    int subtotal = sale.totalAmount + sale.discountAmount;
    String subtotalLabel = localizations?.subtotal ?? '소계';
    String subtotalVal = currencyFormat.format(subtotal);
    String subtotalLine = _padRight('$subtotalLabel:', 42 - _getDisplayWidth(subtotalVal)) + subtotalVal;
    await encoder.text(subtotalLine);
    encoder.lineFeed();

    // Tax details if enabled
    if (settings?.receiptShowTaxDetails != false && sale.taxAmount > 0) {
      encoder.setStyles(bold: false);
      String taxLabel = _translate(localizations, 'taxes.title', '세금');
      String taxVal = currencyFormat.format(sale.taxAmount);
      String taxLine = _padRight('  $taxLabel:', 42 - _getDisplayWidth(taxVal)) + taxVal;
      await encoder.text(taxLine);
      encoder.lineFeed();
    }

    // Discounts
    if (sale.discountAmount > 0) {
      encoder.setStyles(bold: false);
      String discountLabel = localizations?.discount ?? '할인';
      
      if (settings?.receiptShowDiscountDetails != false && sale.cartDiscountsJson != null) {
        try {
          final List<dynamic> cartDiscounts = jsonDecode(sale.cartDiscountsJson!);
          for (var d in cartDiscounts) {
             final dName = d['name'] ?? discountLabel;
             final dAmount = d['amount'] ?? 0;
             if (dAmount > 0) {
               String dVal = '-${currencyFormat.format(dAmount)}';
               String dLine = _padRight('  $dName:', 42 - _getDisplayWidth(dVal)) + dVal;
               await encoder.text(dLine);
               encoder.lineFeed();
             }
          }
        } catch (_) {}
      }

      String totalDiscVal = '-${currencyFormat.format(sale.discountAmount)}';
      String totalDiscLine = _padRight('$discountLabel:', 42 - _getDisplayWidth(totalDiscVal)) + totalDiscVal;
      await encoder.text(totalDiscLine);
      encoder.lineFeed();
    }

    encoder.setStyles(bold: true);
    String totalLabel = _translate(localizations, 'sales.total', '합계');
    String totalVal = currencyFormat.format(sale.totalAmount);
    String totalLine = _padRight('$totalLabel:', 42 - _getDisplayWidth(totalVal)) + totalVal;
    await encoder.text(totalLine);
    encoder.lineFeed(2);
    
    // Footer
    encoder.setStyles(bold: false);
    String paymentMethodLabel = _translate(localizations, 'receipt.paymentMethod', '결제수단');
    await encoder.text('$paymentMethodLabel: ${sale.paymentMethod}');
    encoder.lineFeed(2);
    
    if (settings?.receiptFooter != null && settings!.receiptFooter!.isNotEmpty) {
      encoder.setAlign('center');
      await encoder.text(settings.receiptFooter!);
      encoder.lineFeed(1);
    }

    encoder.setAlign('center');
    await encoder.text(_translate(localizations, 'receipt.thankYouMessage', '이용해 주셔서 감사합니다'));
    encoder.lineFeed(2);
    
    encoder.cut();
    return encoder.bytes;
  }

  static Future<Uint8List> cancelReceipt(
    SaleModel sale, 
    List<SaleItemModel> items, 
    Map<String, ProductModel> productMap, 
    {Map<String, dynamic> storeInfo = const {},
    StoreSettingsModel? settings,
    BuildContext? context}
  ) async {
    print('ReceiptTemplates: Generating cancel receipt for sale ${sale.id}');
    final country = settings?.receiptTemplate?.country ?? 'KR';
    final currencyFormat = LocaleHelper.getCurrencyFormat(country);
    final dateFormat = LocaleHelper.getDateFormat(country);
    
    final storeName = storeInfo['name'] ?? 'POSAce Store';
    final bizNo = storeInfo['businessNumber'] ?? '-';
    final localizations = context != null ? AppLocalizations.of(context) : null;

    final encoder = EscPosEncoder();
    encoder.reset();
    
    // Header
    encoder.setAlign('center');
    String cancelTitle = '*** [${_translate(localizations, 'common.cancel', '취소')}] ***';
    await encoder.text(cancelTitle, bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(1);
    await encoder.text(storeName, bold: true);
    encoder.lineFeed(1);
    await encoder.text('${localizations?.businessNumber ?? '사업자번호'}: $bizNo');
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('${_translate(localizations, 'receipt.cancelDateTime', '취소일시')}: ${dateFormat.format(DateTime.now())}');
    encoder.lineFeed();
    await encoder.text('${_translate(localizations, 'receipt.originalDateTime', '원거래일')}: ${dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.text('${_translate(localizations, 'receipt.transactionNumber', '거래 NO')}: ${sale.id.substring(0, 8)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      final qtyStr = (-item.qty).toString();
      final priceStr = currencyFormat.format(-(item.price * item.qty));

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
    }
    
    await encoder.dashLine();
    
    // Totals
    encoder.setStyles(bold: true);
    int subtotal = sale.totalAmount + sale.discountAmount;
    String subtotalVal = currencyFormat.format(-subtotal);
    await encoder.text(_padRight('${localizations?.subtotal ?? '소계'} ${_translate(localizations, 'common.cancel', '취소')}:', 42 - _getDisplayWidth(subtotalVal)) + subtotalVal);
    encoder.lineFeed();

    String totalVal = currencyFormat.format(-sale.totalAmount);
    await encoder.text(_padRight('${_translate(localizations, 'sales.total', '합계')} ${_translate(localizations, 'common.cancel', '취소')}:', 42 - _getDisplayWidth(totalVal)) + totalVal);
    encoder.lineFeed(2);
    
    encoder.cut();
    return encoder.bytes;
  }

  static Future<Uint8List> kitchenOrder(
    SaleModel sale, 
    List<SaleItemModel> items, 
    Map<String, ProductModel> productMap,
    {Map<String, List<ProductOptionModel>>? itemOptions,
    BuildContext? context}
  ) async {
    print('ReceiptTemplates: Generating kitchen order for sale ${sale.id}');
    final localizations = context != null ? AppLocalizations.of(context) : null;
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    
    final encoder = EscPosEncoder();
    encoder.reset();
    
    encoder.setAlign('center');
    String title = '*** ${_translate(localizations, 'receipt.kitchenOrder', '주방주문서')} ***';
    await encoder.text(title, bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('${_translate(localizations, 'receipt.dateTime', '주문일시')}: ${dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    for (var item in items) {
      final product = productMap[item.productId];
      final name = product?.name ?? 'Unknown';
      
      // 해외 주방 스타일: "2 X 아메리카노"
      await encoder.text('${item.qty} X $name', doubleHeight: true, doubleWidth: true);
      encoder.lineFeed();
      
      // 옵션 출력 (들여쓰기)
      final options = itemOptions?[item.id] ?? [];
      if (options.isNotEmpty) {
        for (var option in options) {
          await encoder.text('   + ${option.name}');
          encoder.lineFeed();
        }
      }
    }
    
    await encoder.dashLine();
    encoder.cut();
    return encoder.bytes;
  }
}

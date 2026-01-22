import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../data/local/models.dart';
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

  static Future<Uint8List> saleReceipt(SaleModel sale, List<SaleItemModel> items, Map<String, ProductModel> productMap, {Map<String, String?> storeInfo = const {}}) async {
    print('ReceiptTemplates: Generating sale receipt for sale ${sale.id}');
    final storeName = storeInfo['name'] ?? 'POSAce Store';
    final bizNo = storeInfo['businessNumber'] ?? '-';
    final address = storeInfo['address']?.replaceAll('||', ' ') ?? '-';
    final phone = storeInfo['phone'] ?? '-';

    final encoder = EscPosEncoder();
    encoder.reset();
    
    // Header
    encoder.setAlign('center');
    await encoder.text(storeName, bold: true, doubleHeight: true, doubleWidth: true);
    encoder.lineFeed(1);
    encoder.setAlign('center');
    await encoder.text('사업자번호: $bizNo');
    encoder.lineFeed();
    await encoder.text('주소: $address');
    encoder.lineFeed();
    await encoder.text('전화: $phone');
    encoder.lineFeed(2);
    
    encoder.setAlign('left');
    await encoder.text('일시: ${_dateFormat.format(sale.createdAt)}');
    encoder.lineFeed();
    await encoder.text('거래 NO: ${sale.id.substring(0, 8)}');
    encoder.lineFeed();
    await encoder.dashLine();
    
    // Items Header (Name: 20, Qty: 6, Amt: 16 -> Total 42)
    String header = _padRight('상품명', 20) + _padLeft('수량', 6) + _padLeft('금액', 16);
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
    }
    
    await encoder.dashLine();
    
    // Totals
    encoder.setStyles(bold: true);
    String totalLabel = '총 금액:';
    String totalVal = _currencyFormat.format(sale.totalAmount);
    // Align total price to right edge
    String totalLine = _padRight(totalLabel, 42 - _getDisplayWidth(totalVal)) + totalVal;
    await encoder.text(totalLine);
    encoder.lineFeed(2);
    
    // Payment
    encoder.setStyles(bold: false);
    await encoder.text('결제수단: ${sale.paymentMethod}');
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
    }
    
    await encoder.dashLine();
    
    // Totals
    encoder.setStyles(bold: true);
    String totalLabel = '취소 금액:';
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

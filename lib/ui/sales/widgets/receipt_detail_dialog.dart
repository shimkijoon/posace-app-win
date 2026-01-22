import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../data/local/app_database.dart';
import '../../../data/local/models.dart';
import '../../../core/printer/serial_printer_service.dart';
import '../../../core/printer/receipt_templates.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/storage/settings_storage.dart';
import '../../../core/storage/auth_storage.dart';

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

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final items = await widget.database.getSaleItems(widget.sale.id);
    final products = await widget.database.getProducts();
    final productMap = {for (var p in products) p.id: p};
    
    if (mounted) {
      setState(() {
        _items = items;
        _productMap = productMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _reprint() async {
    print('ReceiptDetailDialog: Requesting reprint for sale ${widget.sale.id}');
    final printer = SerialPrinterService();
    final settings = SettingsStorage();
    final auth = AuthStorage();

    String? port = await settings.getReceiptPrinterPort();
    int baud = await settings.getReceiptPrinterBaud();

    if (port != null && !printer.isConnected(port)) {
      print('ReceiptDetailDialog: Port $port not connected. Attempting connection...');
      printer.connect(port, baudRate: baud);
    }

    if (port == null || !printer.isConnected(port)) {
      print('ReceiptDetailDialog: Failed to connect to port $port for reprint.');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 프린터를 연결할 수 없습니다.')),
      );
      return;
    }

    final storeInfo = await auth.getSessionInfo();
    final bytes = await ReceiptTemplates.saleReceipt(widget.sale, _items, _productMap, storeInfo: storeInfo);
    print('ReceiptDetailDialog: Reprint receipt generated, sending ${bytes.length} bytes to $port');
    await printer.printBytes(port, bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Dialog(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '영수증 상세',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const Divider(),
            
            // Receipt Preview (Simplified)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('일시: ${DateFormat('yyyy-MM-dd HH:mm').format(widget.sale.createdAt)}'),
                  const Divider(),
                  ..._items.map((item) {
                    final product = _productMap[item.productId];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(product?.name ?? 'Unknown'),
                          Text('x${item.qty}   ${currencyFormat.format(item.price * item.qty)}'),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('총 금액', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(currencyFormat.format(widget.sale.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _reprint,
                    child: const Text('재출력'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.sale.status != 'CANCELLED')
              ElevatedButton(
                onPressed: _cancelOrder,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                child: const Text('주문 취소', style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('주문 취소'),
        content: const Text('현재 주문을 취소하시겠습니까? (취소 영수증이 출력됩니다)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('아니오')),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: AppTheme.error), child: const Text('예, 취소합니다')),
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
      final settings = SettingsStorage();
      final port = await settings.getReceiptPrinterPort();
      final baud = await settings.getReceiptPrinterBaud();

      if (port != null) {
        print('ReceiptDetailDialog: Attempting to print cancellation receipt on $port');
        final printer = SerialPrinterService();
        if (!printer.isConnected(port)) {
          printer.connect(port, baudRate: baud);
        }
        
        if (printer.isConnected(port)) {
          final auth = AuthStorage();
          final storeInfo = await auth.getSessionInfo();
          final bytes = await ReceiptTemplates.cancelReceipt(widget.sale, _items, _productMap, storeInfo: storeInfo);
          print('ReceiptDetailDialog: Cancellation receipt generated, sending ${bytes.length} bytes to $port');
          await printer.printBytes(port, bytes);
        } else {
          print('ReceiptDetailDialog: Cancellation printer $port not connected.');
        }
      }

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

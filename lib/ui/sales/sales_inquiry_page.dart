import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/local/app_database.dart';
import '../../data/local/models.dart';
import '../../core/theme/app_theme.dart';
import '../sales/widgets/title_bar.dart';
import 'widgets/receipt_detail_dialog.dart';

class SalesInquiryPage extends StatefulWidget {
  const SalesInquiryPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SalesInquiryPage> createState() => _SalesInquiryPageState();
}

class _SalesInquiryPageState extends State<SalesInquiryPage> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _toDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() => _isLoading = true);
    try {
      final db = await widget.database.database;
      final maps = await db.query(
        'sales',
        where: 'createdAt BETWEEN ? AND ?',
        whereArgs: [
          _fromDate.toIso8601String().split('T')[0] + 'T00:00:00',
          _toDate.toIso8601String().split('T')[0] + 'T23:59:59',
        ],
        orderBy: 'createdAt DESC',
      );
      
      if (mounted) {
        setState(() {
          _sales = maps.map((m) => SaleModel.fromMap(m)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    }
  }

  void _showReceiptDetail(SaleModel sale) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ReceiptDetailDialog(
        sale: sale,
        database: widget.database,
      ),
    );

    if (result == true) {
      _loadSales();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          TitleBar(
            title: '매출 조회',
            onHomePressed: () => Navigator.pop(context),
          ),
          
          // Filters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _fromDate = picked.start;
                        _toDate = picked.end;
                      });
                      _loadSales();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text('${DateFormat('yyyy-MM-dd').format(_fromDate)} ~ ${DateFormat('yyyy-MM-dd').format(_toDate)}'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadSales,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _sales.length,
                    itemBuilder: (context, index) {
                      final sale = _sales[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          onTap: () => _showReceiptDetail(sale),
                          title: Text('총 금액: ${currencyFormat.format(sale.totalAmount)}'),
                          subtitle: Text('일시: ${dateFormat.format(sale.createdAt)} | 결제: ${sale.paymentMethod}'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

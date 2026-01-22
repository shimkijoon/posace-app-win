import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/app_database.dart';
import '../../../../core/storage/auth_storage.dart';
import '../../../../data/remote/pos_suspended_api.dart';

class SuspendedSalesDialog extends StatefulWidget {
  const SuspendedSalesDialog({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<SuspendedSalesDialog> createState() => _SuspendedSalesDialogState();
}

class _SuspendedSalesDialogState extends State<SuspendedSalesDialog> {
  List<dynamic> _suspendedSales = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuspendedSales();
  }

  Future<void> _loadSuspendedSales() async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];

      if (storeId == null || token == null) throw Exception('인증 정보가 없습니다.');

      final api = PosSuspendedApi(accessToken: token);
      final sales = await api.getSuspendedSales(storeId);
      
      if (mounted) {
        setState(() {
          _suspendedSales = sales;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('보류 주문 로드 실패: $e')));
      }
    }
  }

  Future<void> _deleteSale(String id) async {
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];
      
      if (storeId == null || token == null) return;

      final api = PosSuspendedApi(accessToken: token);
      await api.deleteSuspendedSale(storeId, id);
      _loadSuspendedSales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('보류 주문 삭제 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'ko_KR', symbol: '₩');
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.pause_circle_outline, color: AppTheme.warning),
                const SizedBox(width: 12),
                const Text(
                  '보류 거래 내역',
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
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_suspendedSales.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('보류된 거래가 없습니다.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _suspendedSales.length,
                  itemBuilder: (context, index) {
                    final sale = _suspendedSales[index];
                    final date = DateTime.parse(sale['createdAt']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: ListTile(
                        onTap: () => Navigator.pop(context, sale['id']),
                        title: Text(
                          currencyFormat.format(num.tryParse(sale['totalAmount'].toString()) ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primary),
                        ),
                        subtitle: Text(dateFormat.format(date)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, sale['id']),
                              child: const Text('가져오기'),
                            ),
                            IconButton(
                              onPressed: () => _deleteSale(sale['id']),
                              icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

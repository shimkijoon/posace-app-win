import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/local/app_database.dart';
import '../../../data/remote/api_client.dart';
import '../../../data/remote/table_management_api.dart';
import '../../../core/storage/auth_storage.dart';
import '../../sales/sales_page.dart';

class TableManagementDialog extends StatefulWidget {
  final Map<String, dynamic> table;
  final Map<String, dynamic> activeOrder;
  final List<dynamic> allTables;
  final AppDatabase database;
  final VoidCallback onActionComplete;

  const TableManagementDialog({
    super.key,
    required this.table,
    required this.activeOrder,
    required this.allTables,
    required this.database,
    required this.onActionComplete,
  });

  @override
  State<TableManagementDialog> createState() => _TableManagementDialogState();
}

class _TableManagementDialogState extends State<TableManagementDialog> {
  late TableManagementApi _api;
  final _storage = AuthStorage();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initApi();
  }

  Future<void> _initApi() async {
    final token = await _storage.getAccessToken();
    if (token != null) {
      _api = TableManagementApi(ApiClient(accessToken: token));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '테이블 ${widget.table['name']} 관리',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '주문 합계: ${widget.activeOrder['totalAmount'] ?? 0}원',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // 핵심 액션 버튼 그리드
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 2.5,
              children: [
                _buildActionCard(
                  icon: Icons.point_of_sale,
                  title: '주문 추가/보기',
                  color: AppTheme.primary,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SalesPage(
                          database: widget.database, 
                          tableId: widget.table['id']
                        ),
                      ),
                    );
                  },
                ),
                _buildActionCard(
                  icon: Icons.move_up,
                  title: '테이블 이동',
                  color: Colors.blueAccent,
                  onTap: _onMove,
                ),
                _buildActionCard(
                  icon: Icons.merge_type,
                  title: '주문 합치기 (합석)',
                  color: Colors.purpleAccent,
                  onTap: _onMerge,
                ),
                _buildActionCard(
                  icon: Icons.call_split,
                  title: '주문 나누기 (분리)',
                  color: Colors.orangeAccent,
                  onTap: _onSplit,
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 결제 버튼
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                   // Proceed to checkout logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.payment, color: Colors.white),
                label: const Text('결제하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // --- Actions ---

  Future<void> _onMove() async {
    final targetTable = await _showTableSelectionDialog('이동할 대상을 선택해 주세요', unoccupiedOnly: true);
    if (targetTable == null) return;

    setState(() => _isLoading = true);
    try {
      final session = await _storage.getSessionInfo();
      await _api.moveOrder(
        storeId: session['storeId']!,
        fromTableId: widget.table['id'],
        toTableId: targetTable['id'],
      );
      widget.onActionComplete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onMerge() async {
    final targetTable = await _showTableSelectionDialog('합칠 대상(메인) 테이블을 선택해 주세요', occupiedOnly: true);
    if (targetTable == null) return;

    setState(() => _isLoading = true);
    try {
      final session = await _storage.getSessionInfo();
      await _api.mergeOrders(
        storeId: session['storeId']!,
        sourceTableId: widget.table['id'],
        targetTableId: targetTable['id'],
      );
      widget.onActionComplete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onSplit() async {
    // Placeholder: This needs a more complex UI to select items
    _showError('주문 분리 기능은 상세 상품 선택 UI와 함께 곧 업데이트될 예정입니다.');
  }

  Future<Map<String, dynamic>?> _showTableSelectionDialog(String title, {bool unoccupiedOnly = false, bool occupiedOnly = false}) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: ListView(
            shrinkWrap: true,
            children: widget.allTables.where((t) {
              if (t['id'] == widget.table['id']) return false;
              // Add occupancy check logic here in real usage
              return true;
            }).map((t) => ListTile(
              title: Text('테이블 ${t['name']}'),
              onTap: () => Navigator.pop(context, t),
            )).toList(),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}

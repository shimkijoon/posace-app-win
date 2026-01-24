import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_master_api.dart';
import '../../data/remote/pos_sales_api.dart';
import '../../data/remote/pos_session_api.dart';
import '../../sync/sync_service.dart';
import '../auth/login_page.dart';
import '../sales/sales_page.dart';
import '../sales/sales_inquiry_page.dart';
import '../tables/table_layout_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = AuthStorage();
  final _settingsStorage = SettingsStorage();
  Map<String, String?> _session = {};
  int _unsyncedSalesCount = 0;
  String? _currentEmployeeName;
  bool _isSessionActive = false;
  String? _currentSessionId;
  bool _usePosSession = true;
  List<Map<String, dynamic>> _weeklySales = [];

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadDataCounts();
    _loadWeeklySales();
  }

  Future<void> _loadSession() async {
    final session = await _storage.getSessionInfo();
    final useSession = await _settingsStorage.getUsePosSession();
    if (!mounted) return;
    setState(() {
      _session = session;
      _currentSessionId = session['sessionId'];
      _isSessionActive = session['sessionId'] != null;
      _usePosSession = useSession;
    });
    
  }

  Future<void> _loadDataCounts() async {
    final unsyncedSales = await widget.database.getUnsyncedSales();
    final employees = await widget.database.getEmployees();
    final currentEmployeeId = _session['employeeId'];
    
    String? employeeName;
    if (currentEmployeeId != null) {
      try {
        final emp = employees.firstWhere((e) => e.id == currentEmployeeId);
        employeeName = emp.name;
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _unsyncedSalesCount = unsyncedSales.length;
      _currentEmployeeName = employeeName;
    });
  }

  Future<void> _loadWeeklySales() async {
    final sales = await widget.database.getWeeklySales();
    if (!mounted) return;
    setState(() {
      _weeklySales = sales;
    });
  }


  Future<void> _logout() async {
    await _storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LoginPage(database: widget.database)),
    );
  }

  Future<void> _handleOpenSession() async {
    final amountController = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영업 시작 (세션 열기)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('영업 준비금(시재)을 입력하세요.'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('영업 시작'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final openingAmount = int.tryParse(amountController.text) ?? 0;
    
    try {
      final accessToken = await _storage.getAccessToken();
      final storeId = _session['storeId'];
      
      if (accessToken == null || storeId == null) return;

      final apiClient = ApiClient(accessToken: accessToken);
      final sessionApi = PosSessionApi(apiClient);
      
      final result = await sessionApi.openSession(storeId, openingAmount);
      
      // Save Session ID
      final sessionId = result['id']; // Assuming API returns object with id
      await _storage.savePosSession(sessionId);

      await _loadSession(); // Refresh UI state
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영업이 시작되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('세션 시작 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _handleCloseSession() async {
    final amountController = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('영업 마감 (세션 종료)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('최종 시재(현금 잔액)를 입력하세요.'),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '금액',
                border: OutlineInputBorder(),
                suffixText: '원',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('영업 마감'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final closingAmount = int.tryParse(amountController.text) ?? 0;
    
    try {
      final accessToken = await _storage.getAccessToken();
      final sessionId = _currentSessionId;
      
      if (accessToken == null || sessionId == null) return;

      final apiClient = ApiClient(accessToken: accessToken);
      final sessionApi = PosSessionApi(apiClient);
      
      // For now, passing 0 as computed totalCash as specific implementation might vary
      await sessionApi.closeSession(sessionId, closingAmount, 0);
      
      // Clear Session ID
      await _storage.savePosSession(null);

      await _loadSession(); // Refresh UI state
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영업이 마감되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('세션 종료 실패: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('POSAce Windows', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('로그아웃'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '오늘의 매장 현황',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // 매장 정보 & 영업 상태 Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInfoCard(
                        title: '매장 정보',
                        icon: Icons.store,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildInfoRow('매장명', _session['name'] ?? '-', isBold: true),
                          _buildInfoRow('사업자번호', _session['businessNumber'] ?? '-'),
                          _buildInfoRow('전화번호', _session['phone'] ?? '-'),
                          _buildInfoRow('주소', _session['address'] ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildInfoCard(
                        title: '영업 상태',
                        icon: Icons.access_time_filled,
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 4),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _usePosSession 
                                    ? (_isSessionActive ? "영업 중" : "영업 종료")
                                    : "영업 미사용",
                                  style: TextStyle(
                                    color: (_usePosSession && !_isSessionActive) ? AppTheme.error : AppTheme.success, 
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_usePosSession)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSessionActive ? _handleCloseSession : _handleOpenSession,
                                      icon: Icon(_isSessionActive ? Icons.logout : Icons.login, size: 16),
                                      label: Text(_isSessionActive ? '영업 마감' : '영업 시작', style: const TextStyle(fontSize: 13)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isSessionActive ? AppTheme.error : AppTheme.success,
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // 마스터 데이터 동기화 섹션
                const Text(
                  '관리 도구',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  title: '주간 매출 추이',
                  icon: Icons.show_chart,
                  padding: const EdgeInsets.all(16),
                  children: [
                    SizedBox(
                      height: 150,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16, top: 8),
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true, drawVerticalLine: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 50,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${(value / 1000).toStringAsFixed(0)}K',
                                      style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 1, // Show label for every data point (0, 1, 2, 3, 4, 5, 6)
                                  reservedSize: 30,
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index >= 0 && index < _weeklySales.length) {
                                      final dateStr = _weeklySales[index]['date'] as String;
                                      final date = DateTime.parse(dateStr);
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          '${date.month}/${date.day}',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _weeklySales.asMap().entries.map((entry) {
                                  final total = (entry.value['total'] as num?)?.toDouble() ?? 0.0;
                                  return FlSpot(entry.key.toDouble(), total);
                                }).toList(),
                                isCurved: true,
                                color: AppTheme.primary,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: AppTheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Single row of action buttons
                SizedBox(
                  height: 100,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildMainActionButton(
                          onPressed: (!_usePosSession || _isSessionActive)
                              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesPage(database: widget.database)))
                              : null,
                          icon: Icons.receipt_long,
                          label: '판매 시작',
                          color: AppTheme.primary,
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _buildMainActionButton(
                          onPressed: (!_usePosSession || _isSessionActive)
                              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TableLayoutPage(database: widget.database)))
                              : null,
                          icon: Icons.table_restaurant,
                          label: '테이블 주문',
                          color: const Color(0xFF6366F1),
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildSecondaryActionButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesInquiryPage(database: widget.database))),
                          icon: Icons.history,
                          label: '매출 내역\n조회',
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildSecondaryActionButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(database: widget.database))),
                          icon: Icons.settings,
                          label: '포스 설정',
                          height: double.infinity,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, List<Widget>? children, Widget? trailing, EdgeInsets? padding}) {
    return Card(
      child: Padding(
        padding: padding ?? const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppTheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (trailing != null) trailing,
              ],
            ),
            const SizedBox(height: 12),
            if (children != null) ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: AppTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, {bool highlight = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: highlight ? AppTheme.error.withOpacity(0.1) : AppTheme.background,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: highlight ? AppTheme.error : AppTheme.textSecondary, size: 18),
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: highlight ? AppTheme.error : AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildMainActionButton({required VoidCallback? onPressed, required IconData icon, required String label, required Color color, double height = 120}) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: AppTheme.border,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: Colors.white),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActionButton({required VoidCallback onPressed, required IconData icon, required String label, double height = 80}) {
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 14)),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: const BorderSide(color: AppTheme.border, width: 1.5),
          backgroundColor: AppTheme.surface,
        ),
      ),
    );
  }
}

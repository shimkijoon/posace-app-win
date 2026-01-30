import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/app_localizations.dart';
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
import '../../core/version_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = AuthStorage();
  final _settingsStorage = SettingsStorage();
  Map<String, dynamic> _session = {};
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
    _checkUpdate();
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
        title: Text(AppLocalizations.of(context)!.translate('home.startBusiness')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.translate('home.enterOpeningAmount')),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.translate('session.amount'),
                border: const OutlineInputBorder(),
                suffixText: AppLocalizations.of(context)!.translate('session.won'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppLocalizations.of(context)!.translate('home.startBusiness')),
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.translate('session.businessStarted') ?? '영업이 시작되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('session.startFailed') ?? '세션 시작 실패'}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCloseSession() async {
    final amountController = TextEditingController(text: '0');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('session.closeBusiness')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.enterClosingAmount),
            const SizedBox(height: 8),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.translate('session.amount'),
                border: const OutlineInputBorder(),
                suffixText: AppLocalizations.of(context)!.translate('session.won'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.closeBusiness),
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

  Future<void> _checkUpdate() async {
    final updateInfo = await VersionService().checkUpdate();
    if (updateInfo != null && mounted) {
      _showUpdateDialog(updateInfo);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !(updateInfo['mandatory'] ?? false),
      builder: (context) => AlertDialog(
        title: Text('새로운 버전 업데이트 (${updateInfo['version']})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('최신 버전이 출시되었습니다. 업데이트하시겠습니까?'),
            const SizedBox(height: 12),
            const Text('변경사항:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text(updateInfo['changelog'] ?? '안정성 개선 및 버그 수정', style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          if (!(updateInfo['mandatory'] ?? false))
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)!.translate('common.later') ?? '나중에'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(updateInfo['url']);
            },
            child: Text(AppLocalizations.of(context)!.translate('common.updateNow') ?? '지금 업데이트'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('업데이트 페이지를 열 수 없습니다.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, size: 18),
              label: Text(AppLocalizations.of(context)!.logout),
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
                Text(
                  AppLocalizations.of(context)!.todayStoreStatus,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                
                // 매장 정보 & 영업 상태 Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildInfoCard(
                        title: AppLocalizations.of(context)!.storeInfo,
                        icon: Icons.store,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildInfoRow(AppLocalizations.of(context)!.storeName, _session['name'] ?? '-', isBold: true),
                          _buildInfoRow(AppLocalizations.of(context)!.businessNumber, _session['businessNumber'] ?? '-'),
                          _buildInfoRow(AppLocalizations.of(context)!.phone, _session['phone'] ?? '-'),
                          _buildInfoRow(AppLocalizations.of(context)!.address, _session['address'] ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildInfoCard(
                        title: AppLocalizations.of(context)!.operatingStatus,
                        icon: Icons.access_time_filled,
                        padding: const EdgeInsets.all(16),
                        children: [
                          const SizedBox(height: 4),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _usePosSession 
                                    ? (_isSessionActive ? AppLocalizations.of(context)!.operating : AppLocalizations.of(context)!.closed)
                                    : AppLocalizations.of(context)!.translate('home.sessionNotUsed'),
                                  style: TextStyle(
                                    color: (_usePosSession && !_isSessionActive) ? AppTheme.error : AppTheme.success, 
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (_usePosSession)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSessionActive ? _handleCloseSession : _handleOpenSession,
                                      icon: Icon(_isSessionActive ? Icons.logout : Icons.login, size: 16),
                                      label: Text(_isSessionActive ? AppLocalizations.of(context)!.closeBusiness : AppLocalizations.of(context)!.translate('home.startBusiness'), style: const TextStyle(fontSize: 13)),
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
                Text(
                  AppLocalizations.of(context)!.managementTools,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildInfoCard(
                  title: AppLocalizations.of(context)!.weeklySalesTrend,
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
                          label: AppLocalizations.of(context)!.startSale,
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
                          label: AppLocalizations.of(context)!.tableOrder,
                          color: AppTheme.secondary,
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildSecondaryActionButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesInquiryPage(database: widget.database))),
                          icon: Icons.history,
                          label: AppLocalizations.of(context)!.salesHistory,
                          height: double.infinity,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _buildSecondaryActionButton(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsPage(database: widget.database))),
                          icon: Icons.settings,
                          label: AppLocalizations.of(context)!.posSettings,
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
                    Icon(icon, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
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

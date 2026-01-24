import 'package:flutter/material.dart';
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
  bool _syncing = false;
  String? _syncStatus;
  int _categoriesCount = 0;
  int _productsCount = 0;
  int _discountsCount = 0;
  int _unsyncedSalesCount = 0;
  String? _currentEmployeeName;
  bool _isSessionActive = false;
  String? _currentSessionId;
  bool _usePosSession = true;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadDataCounts();
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
    
    // 자동 동기화 (최초 로그인 또는 당일 최초 실행 시)
    if (session['storeId'] != null) {
      final lastSync = await _settingsStorage.getLastSyncAt();
      final now = DateTime.now();
      
      // 당일 동기화 기록이 없거나, 날짜가 바뀌었으면 실행
      if (lastSync == null || 
          lastSync.year != now.year || 
          lastSync.month != now.month || 
          lastSync.day != now.day) {
        _syncMaster(auto: true);
      }
    }

    _startScheduledSyncTimer();
  }

  void _startScheduledSyncTimer() {
    // 1분마다 체크하여 스케줄된 시간에 동기화 수행
    Stream.periodic(const Duration(minutes: 1)).listen((_) async {
      if (_syncing) return;
      
      final scheduledTimes = await _settingsStorage.getScheduledSyncTimes();
      final now = DateTime.now();
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      
      if (scheduledTimes.contains(currentTime)) {
        if (mounted && _session['storeId'] != null) {
          _syncMaster(auto: true);
        }
      }
    });
  }

  Future<void> _loadDataCounts() async {
    final categories = await widget.database.getCategories();
    final products = await widget.database.getProducts();
    final discounts = await widget.database.getDiscounts();
    final unsyncedSales = await widget.database.getUnsyncedSales();
    final activeSession = await widget.database.getActiveSession();
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
      _categoriesCount = categories.length;
      _productsCount = products.length;
      _discountsCount = discounts.length;
      _unsyncedSalesCount = unsyncedSales.length;
      // We trust AuthStorage for session state mostly, but local DB check is good too
      // _isSessionActive = activeSession != null; 
      // Let's use AuthStorage as primary source of truth for "active session" ID from server perspective
      _currentEmployeeName = employeeName;
    });
  }

  Future<void> _syncMaster({bool auto = false}) async {
    final storeId = _session['storeId'];
    final accessToken = await _storage.getAccessToken();
    
    if (storeId == null || accessToken == null) {
      return;
    }

    setState(() {
      _syncing = true;
      _syncStatus = auto ? '자동 동기화 중...' : '동기화 중...';
    });

    try {
      final apiClient = ApiClient(accessToken: accessToken);
      final masterApi = PosMasterApi(apiClient);
      final salesApi = PosSalesApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: salesApi,
      );

      // 1. 마스터 동기화
      final result = await syncService.syncMaster(
        storeId: storeId,
        manual: !auto,
      );

      // 2. 미동기화 매출 업로드
      int uploadedCount = 0;
      if (result.success) {
        uploadedCount = await syncService.flushSalesQueue();
      }

      if (!mounted) return;

      if (result.success) {
        await _settingsStorage.setLastSyncAt(DateTime.now());
        setState(() {
          _syncStatus = '동기화 완료';
          _categoriesCount = result.categoriesCount ?? 0;
          _productsCount = result.productsCount ?? 0;
          _discountsCount = result.discountsCount ?? 0;
        });
        
        if (!auto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '동기화 완료: 마스터(${result.productsCount ?? 0}개), 매출($uploadedCount건) 업로드',
              ),
            ),
          );
        }
      } else {
        setState(() {
          _syncStatus = '동기화 실패: ${result.error}';
        });
        if (!auto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('동기화 실패: ${result.error}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '동기화 오류: $e';
      });
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 오류: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
        await _loadDataCounts();
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('로컬의 모든 데이터를 삭제하고 서버에서 다시 불러오시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('예, 초기화합니다'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _syncing = true;
      _syncStatus = '데이터 초기화 중...';
    });

    try {
      final accessToken = await _storage.getAccessToken();
      final apiClient = ApiClient(accessToken: accessToken!);
      final masterApi = PosMasterApi(apiClient);
      final salesApi = PosSalesApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: salesApi,
      );

      await syncService.clearLocalData();
      await _syncMaster(auto: false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '초기화 오류: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 중 오류 발생: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
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

      setState(() { _syncing = true; }); // Show loading

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

      // 개점 시 동기화 수행
      _syncMaster(auto: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('세션 시작 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _syncing = false; });
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

      setState(() { _syncing = true; });

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

      // 마감 시 동기화 수행
      _syncMaster(auto: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('세션 종료 실패: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _syncing = false; });
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
                          _buildInfoRow('Store ID', _session['storeId'] ?? '-'),
                          _buildInfoRow('지점명', _session['name'] ?? '본점'),
                          const Divider(height: 16),
                          _buildInfoRow('담당 직원', _currentEmployeeName ?? '미지정', isBold: true),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                const SizedBox(height: 12),
                                if (_usePosSession)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSessionActive ? _handleCloseSession : (_productsCount > 0 ? _handleOpenSession : null),
                                      icon: Icon(_isSessionActive ? Icons.logout : Icons.login, size: 18),
                                      label: Text(_isSessionActive ? '영업 마감' : '영업 시작'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isSessionActive ? AppTheme.error : AppTheme.success,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
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
                
                const SizedBox(height: 20),
                
                // 마스터 데이터 동기화 섹션
                const Text(
                  '관리 도구',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: '데이터 동기화',
                  icon: Icons.sync,
                  padding: const EdgeInsets.all(16),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: _syncing ? null : _resetData,
                        icon: const Icon(Icons.refresh, color: AppTheme.error, size: 16),
                        label: const Text('초기화', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton.icon(
                        onPressed: _syncing ? null : () => _syncMaster(),
                        icon: _syncing
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.sync, size: 16),
                        label: const Text('동기화', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                      ),
                    ],
                  ),
                  children: [
                    if (_syncStatus != null) ...[
                      Text(
                        _syncStatus!,
                        style: TextStyle(
                          color: _syncStatus!.contains('완료') ? AppTheme.success : (_syncStatus!.contains('실패') || _syncStatus!.contains('오류') ? AppTheme.error : AppTheme.textSecondary),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('카테고리', _categoriesCount, Icons.category_outlined),
                        _buildStatItem('상품', _productsCount, Icons.inventory_2_outlined),
                        _buildStatItem('할인', _discountsCount, Icons.local_offer_outlined),
                        _buildStatItem('미전송 매출', _unsyncedSalesCount, Icons.cloud_upload_outlined, highlight: _unsyncedSalesCount > 0),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 실행 버튼 Row (More compact)
                Row(
                  children: [
                    Expanded(
                      child: _buildMainActionButton(
                        onPressed: _productsCount > 0 && (!_usePosSession || _isSessionActive)
                            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesPage(database: widget.database)))
                            : null,
                        icon: Icons.receipt_long,
                        label: '판매 시작',
                        color: AppTheme.primary,
                        height: 100,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMainActionButton(
                        onPressed: _productsCount > 0 && (!_usePosSession || _isSessionActive)
                            ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TableLayoutPage(database: widget.database)))
                            : null,
                        icon: Icons.table_restaurant,
                        label: '테이블 주문',
                        color: const Color(0xFF6366F1),
                        height: 100,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildSecondaryActionButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SalesInquiryPage(database: widget.database))),
                        icon: Icons.history,
                        label: '매출 내역 조회',
                        height: 60,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSecondaryActionButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsPage())),
                        icon: Icons.settings,
                        label: '포스 설정',
                        height: 60,
                      ),
                    ),
                  ],
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

import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_master_api.dart';
import '../../data/remote/pos_sales_api.dart';
import '../../sync/sync_service.dart';
import '../auth/login_page.dart';
import '../sales/sales_page.dart';
import '../sales/sales_inquiry_page.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = AuthStorage();
  Map<String, String?> _session = {};
  bool _syncing = false;
  String? _syncStatus;
  int _categoriesCount = 0;
  int _productsCount = 0;
  int _discountsCount = 0;
  int _unsyncedSalesCount = 0;

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadDataCounts();
  }

  Future<void> _loadSession() async {
    final session = await _storage.getSessionInfo();
    if (!mounted) return;
    setState(() {
      _session = session;
    });
    
    // 자동 동기화 (최초 로그인 시)
    if (session['storeId'] != null) {
      _syncMaster(auto: true);
    }
  }

  Future<void> _loadDataCounts() async {
    final categories = await widget.database.getCategories();
    final products = await widget.database.getProducts();
    final discounts = await widget.database.getDiscounts();
    final unsyncedSales = await widget.database.getUnsyncedSales();
    if (!mounted) return;
    setState(() {
      _categoriesCount = categories.length;
      _productsCount = products.length;
      _discountsCount = discounts.length;
      _unsyncedSalesCount = unsyncedSales.length;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POSAce Windows'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'POSAce Windows Client',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '매장 정보',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('Store ID: ${_session['storeId'] ?? '-'}'),
                    Text('POS ID: ${_session['posId'] ?? '-'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '마스터 데이터',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _syncing ? null : _resetData,
                              icon: const Icon(Icons.delete_forever, color: Colors.red),
                              label: const Text('데이터 초기화', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _syncing ? null : () => _syncMaster(),
                              icon: _syncing
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.sync),
                              label: const Text('동기화'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_syncStatus != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _syncStatus!,
                        style: TextStyle(
                          color: _syncStatus!.contains('완료')
                              ? Colors.green
                              : _syncStatus!.contains('실패') || _syncStatus!.contains('오류')
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard('카테고리', _categoriesCount),
                        _buildStatCard('상품', _productsCount),
                        _buildStatCard('할인', _discountsCount),
                        _buildStatCard('미전송 매출', _unsyncedSalesCount, highlight: _unsyncedSalesCount > 0),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 매출 조회 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SalesInquiryPage(database: widget.database),
                    ),
                  );
                },
                icon: const Icon(Icons.history, size: 24),
                label: const Text(
                  '매출 조회',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // 환경설정 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.settings, size: 24),
                label: const Text(
                  '환경설정',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // 판매 시작 버튼
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _productsCount > 0
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SalesPage(database: widget.database),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.point_of_sale, size: 24),
                label: const Text(
                  '판매 시작',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count, {bool highlight = false}) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            color: highlight ? Colors.orange : null,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

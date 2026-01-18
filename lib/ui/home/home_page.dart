import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_master_api.dart';
import '../../sync/sync_service.dart';
import '../auth/login_page.dart';

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
    if (!mounted) return;
    setState(() {
      _categoriesCount = categories.length;
      _productsCount = products.length;
      _discountsCount = discounts.length;
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
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
      );

      final result = await syncService.syncMaster(
        storeId: storeId,
        manual: !auto,
      );

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
                '동기화 완료: 카테고리 ${result.categoriesCount ?? 0}개, '
                '상품 ${result.productsCount ?? 0}개, '
                '할인 ${result.discountsCount ?? 0}개',
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int count) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

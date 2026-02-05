import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../data/models/unified_order.dart';
import '../../data/remote/unified_order_api.dart';
import '../../data/remote/api_client.dart';
import '../../data/local/app_database.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../core/cache/order_cache_service.dart';
import 'widgets/order_card.dart';
import 'widgets/cooking_queue_section.dart';
import 'widgets/order_filter_bar.dart';

class UnifiedOrderManagementPage extends StatefulWidget {
  final AppDatabase database;

  const UnifiedOrderManagementPage({
    Key? key,
    required this.database,
  }) : super(key: key);

  @override
  State<UnifiedOrderManagementPage> createState() => _UnifiedOrderManagementPageState();
}

class _UnifiedOrderManagementPageState extends State<UnifiedOrderManagementPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late UnifiedOrderApi _orderApi;
  late AuthStorage _storage;
  late OrderCacheService _cacheService;
  
  List<UnifiedOrder> _allOrders = [];
  List<UnifiedOrder> _cookingQueue = [];
  List<UnifiedOrder> _takeoutOrders = [];
  List<UnifiedOrder> _tableOrders = [];
  
  bool _isLoading = false;
  String? _selectedStatus;
  OrderType? _selectedType;
  String? _currentStoreId;
  
  // 실시간 업데이트를 위한 스트림 구독
  StreamSubscription<List<UnifiedOrder>>? _ordersStreamSubscription;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _storage = AuthStorage();
    _cacheService = OrderCacheService();
    _initializeApi();
    _setupRealTimeUpdates();
    
    // 30초마다 자동 새로고침
    _startAutoRefresh();
  }

  Future<void> _initializeApi() async {
    try {
      final accessToken = await _storage.getAccessToken();
      if (accessToken != null) {
        final apiClient = ApiClient(accessToken: accessToken);
        _orderApi = UnifiedOrderApi(apiClient);
        
        // storeId 가져오기 (세션에서)
        final session = await _storage.getSessionInfo();
        _currentStoreId = session['storeId'];
        
        _loadOrders();
      }
    } catch (e) {
      print('Failed to initialize API: $e');
    }
  }

  /// 실시간 업데이트 설정
  void _setupRealTimeUpdates() {
    // 캐시 스트림 구독
    _ordersStreamSubscription = _cacheService.ordersStream.listen((orders) {
      if (mounted) {
        setState(() {
          // 현재 탭에 따라 적절한 목록 업데이트
          switch (_tabController.index) {
            case 0:
              _allOrders = orders;
              break;
            case 1:
              _cookingQueue = orders;
              break;
            case 2:
              _takeoutOrders = orders;
              break;
            case 3:
              _tableOrders = orders;
              break;
          }
        });
      }
    });

    // 주기적 새로고침 타이머 (캐시 만료 시점에 맞춰 60초)
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      if (mounted) {
        _loadOrders(useCache: false); // 캐시 우회하여 서버에서 최신 데이터 가져오기
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ordersStreamSubscription?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    Future.delayed(const Duration(seconds: 30), () {
      if (mounted) {
        _loadOrders();
        _startAutoRefresh();
      }
    });
  }

  Future<void> _loadOrders({bool useCache = true}) async {
    if (!mounted || _currentStoreId == null) return;
    
    setState(() => _isLoading = true);

    try {
      // 병렬로 데이터 로드 (캐시 사용 옵션 포함)
      final futures = await Future.wait([
        _orderApi.getOrders(storeId: _currentStoreId!, limit: 200, useCache: useCache),
        _orderApi.getCookingQueue(_currentStoreId!, useCache: useCache),
        _orderApi.getTakeoutOrders(_currentStoreId!),
        _orderApi.getTableOrders(_currentStoreId!),
      ]);

      if (mounted) {
        setState(() {
          _allOrders = futures[0] as List<UnifiedOrder>;
          _cookingQueue = futures[1] as List<UnifiedOrder>;
          _takeoutOrders = futures[2] as List<UnifiedOrder>;
          _tableOrders = futures[3] as List<UnifiedOrder>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주문 데이터 로드 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, UnifiedOrderStatus status) async {
    try {
      await _orderApi.updateOrderStatus(orderId, status);
      _loadOrders(); // 새로고침
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('주문 상태가 업데이트되었습니다')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('상태 업데이트 실패: $e')),
      );
    }
  }

  Future<void> _updateCookingStatus(String orderId, CookingStatus status) async {
    try {
      await _orderApi.updateCookingStatus(orderId, status);
      _loadOrders(); // 새로고침
      
      String message = '';
      switch (status) {
        case CookingStatus.IN_PROGRESS:
          message = '조리를 시작했습니다';
          break;
        case CookingStatus.COMPLETED:
          message = '조리가 완료되었습니다';
          break;
        case CookingStatus.WAITING:
          message = '조리 대기 상태로 변경되었습니다';
          break;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('조리 상태 업데이트 실패: $e')),
      );
    }
  }

  List<UnifiedOrder> _getFilteredOrders(List<UnifiedOrder> orders) {
    var filtered = orders;
    
    if (_selectedStatus != null) {
      filtered = filtered.where((order) => order.status.name == _selectedStatus).toList();
    }
    
    if (_selectedType != null) {
      filtered = filtered.where((order) => order.type == _selectedType).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('통합 주문 관리'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: 주문 관리 설정 화면
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: '조리 대기열',
              icon: Badge(
                label: Text('${_cookingQueue.length}'),
                child: const Icon(Icons.restaurant),
              ),
            ),
            Tab(
              text: '테이크아웃',
              icon: Badge(
                label: Text('${_takeoutOrders.length}'),
                child: const Icon(Icons.takeout_dining),
              ),
            ),
            Tab(
              text: '테이블',
              icon: Badge(
                label: Text('${_tableOrders.length}'),
                child: const Icon(Icons.table_restaurant),
              ),
            ),
            Tab(
              text: '전체',
              icon: Badge(
                label: Text('${_allOrders.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // 필터 바
          OrderFilterBar(
            selectedStatus: _selectedStatus,
            selectedType: _selectedType,
            onStatusChanged: (status) => setState(() => _selectedStatus = status),
            onTypeChanged: (type) => setState(() => _selectedType = type),
            onClearFilters: () => setState(() {
              _selectedStatus = null;
              _selectedType = null;
            }),
          ),
          
          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 조리 대기열
                CookingQueueSection(
                  orders: _getFilteredOrders(_cookingQueue),
                  isLoading: _isLoading,
                  onStartCooking: (orderId) => _updateCookingStatus(orderId, CookingStatus.IN_PROGRESS),
                  onCompleteCooking: (orderId) => _updateCookingStatus(orderId, CookingStatus.COMPLETED),
                  onRefresh: _loadOrders,
                ),
                
                // 테이크아웃 주문
                _buildOrderList(
                  _getFilteredOrders(_takeoutOrders),
                  emptyMessage: '테이크아웃 주문이 없습니다',
                ),
                
                // 테이블 주문
                _buildOrderList(
                  _getFilteredOrders(_tableOrders),
                  emptyMessage: '테이블 주문이 없습니다',
                ),
                
                // 전체 주문
                _buildOrderList(
                  _getFilteredOrders(_allOrders),
                  emptyMessage: '주문이 없습니다',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<UnifiedOrder> orders, {required String emptyMessage}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              label: const Text('새로고침'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OrderCard(
              order: order,
              onStatusUpdate: _updateOrderStatus,
              onCookingStatusUpdate: _updateCookingStatus,
              onTap: () => _showOrderDetail(order),
            ),
          );
        },
      ),
    );
  }

  void _showOrderDetail(UnifiedOrder order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('주문 상세 - ${order.orderNumber}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('주문 타입', order.type.name),
              _buildDetailRow('상태', order.statusDisplayText),
              _buildDetailRow('조리 상태', order.cookingStatusDisplayText),
              _buildDetailRow('총 금액', '₩${NumberFormat('#,###').format(order.totalAmount)}'),
              _buildDetailRow('주문 시간', DateFormat('MM/dd HH:mm').format(order.createdAt)),
              
              if (order.customerName != null)
                _buildDetailRow('고객명', order.customerName!),
              if (order.customerPhone != null)
                _buildDetailRow('연락처', order.customerPhone!),
              if (order.scheduledTime != null)
                _buildDetailRow('예약 시간', DateFormat('MM/dd HH:mm').format(order.scheduledTime!)),
              if (order.table != null)
                _buildDetailRow('테이블', order.table!['tableNumber'] ?? ''),
              if (order.note != null)
                _buildDetailRow('메모', order.note!),
              
              const SizedBox(height: 16),
              const Text('주문 아이템:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('${item.productName} x${item.qty}'),
                    ),
                    Text('₩${NumberFormat('#,###').format(item.totalPrice)}'),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
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
import '../../core/i18n/app_localizations.dart';
import 'widgets/order_card.dart';
import 'widgets/cooking_queue_section.dart';
import 'widgets/order_filter_bar.dart';
import '../common/navigation_title_bar.dart';
import '../common/navigation_tab.dart';
import '../tables/table_layout_page.dart';

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
    _tabController = TabController(length: 6, vsync: this);
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
              _allOrders = orders;
              break;
            case 3:
              _takeoutOrders = orders;
              break;
            case 4:
              _tableOrders = orders;
              break;
            case 5:
              _allOrders = orders;
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
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.translate('orders.snackbar.loadFailed').replaceAll('{error}', '$e'),
            ),
          ),
        );
      }
    }
  }

  Future<void> _updateOrderStatus(String orderId, UnifiedOrderStatus status) async {
    try {
      await _orderApi.updateOrderStatus(orderId, status);
      _loadOrders(); // 새로고침
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.translate('orders.snackbar.statusUpdated')),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.translate('orders.snackbar.statusUpdateFailed').replaceAll('{error}', '$e'),
          ),
        ),
      );
    }
  }

  Future<void> _updateCookingStatus(String orderId, CookingStatus status) async {
    try {
      await _orderApi.updateCookingStatus(orderId, status);
      // 조리 상태와 주문 상태를 함께 갱신
      if (status == CookingStatus.IN_PROGRESS) {
        await _orderApi.updateOrderStatus(orderId, UnifiedOrderStatus.COOKING);
      }
      if (status == CookingStatus.COMPLETED) {
        await _orderApi.updateOrderStatus(orderId, UnifiedOrderStatus.READY);
      }
      _loadOrders(); // 새로고침
      
      String message = '';
      switch (status) {
        case CookingStatus.IN_PROGRESS:
          message = AppLocalizations.of(context)!.translate('orders.snackbar.cookingStart');
          break;
        case CookingStatus.COMPLETED:
          message = AppLocalizations.of(context)!.translate('orders.snackbar.cookingComplete');
          break;
        case CookingStatus.WAITING:
          message = AppLocalizations.of(context)!.translate('orders.snackbar.cookingWaiting');
          break;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.translate('orders.snackbar.cookingUpdateFailed').replaceAll('{error}', '$e'),
          ),
        ),
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

  List<UnifiedOrder> _getUnpaidOrders() {
    return _allOrders.where((order) => !order.isPaid).toList();
  }

  List<UnifiedOrder> _getWaitingOrders() {
    return _allOrders
        .where((order) => order.status == UnifiedOrderStatus.PENDING)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          NavigationTitleBar(
            currentTab: NavigationTab.orders,
            database: widget.database,
          ),
          // 새로고침 버튼을 포함한 상단 액션 바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(
                bottom: BorderSide(color: AppTheme.border, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadOrders,
                  tooltip: AppLocalizations.of(context)!.translate('orders.tooltip.refresh'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings),
                  onPressed: () {
                    // TODO: 주문 관리 설정 화면
                  },
                  tooltip: AppLocalizations.of(context)!.translate('orders.tooltip.settings'),
                ),
              ],
            ),
          ),
          // 탭 바
          Container(
            color: AppTheme.primary,
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.waiting'),
              icon: Badge(
                label: Text('${_getWaitingOrders().length}'),
                child: const Icon(Icons.queue),
              ),
            ),
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.cookingQueue'),
              icon: Badge(
                label: Text('${_cookingQueue.length}'),
                child: const Icon(Icons.restaurant),
              ),
            ),
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.unpaid'),
              icon: Badge(
                label: Text('${_getUnpaidOrders().length}'),
                child: const Icon(Icons.payments_outlined),
              ),
            ),
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.takeout'),
              icon: Badge(
                label: Text('${_takeoutOrders.length}'),
                child: const Icon(Icons.takeout_dining),
              ),
            ),
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.table'),
              icon: Badge(
                label: Text('${_tableOrders.length}'),
                child: const Icon(Icons.table_restaurant),
              ),
            ),
            Tab(
              text: AppLocalizations.of(context)!.translate('orders.tabs.all'),
              icon: Badge(
                label: Text('${_allOrders.length}'),
                child: const Icon(Icons.list_alt),
              ),
            ),
              ],
            ),
          ),
          // 메인 콘텐츠
          Expanded(
            child: Column(
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
                      // 대기 주문
                      _buildOrderList(
                        _getFilteredOrders(_getWaitingOrders()),
                        emptyMessage: AppLocalizations.of(context)!.translate('orders.empty.waiting'),
                      ),

                      // 조리 대기열
                      CookingQueueSection(
                        orders: _getFilteredOrders(_cookingQueue),
                        isLoading: _isLoading,
                        onStartCooking: (orderId) => _updateCookingStatus(orderId, CookingStatus.IN_PROGRESS),
                        onCompleteCooking: (orderId) => _updateCookingStatus(orderId, CookingStatus.COMPLETED),
                        onRefresh: _loadOrders,
                      ),

                      // 결제 대기 주문
                      _buildOrderList(
                        _getFilteredOrders(_getUnpaidOrders()),
                        emptyMessage: AppLocalizations.of(context)!.translate('orders.empty.unpaid'),
                      ),
                      
                      // 테이크아웃 주문
                      _buildOrderList(
                        _getFilteredOrders(_takeoutOrders),
                        emptyMessage: AppLocalizations.of(context)!.translate('orders.empty.takeout'),
                      ),
                      
                      // 테이블 주문
                      _buildOrderList(
                        _getFilteredOrders(_tableOrders),
                        emptyMessage: AppLocalizations.of(context)!.translate('orders.empty.table'),
                      ),
                      
                      // 전체 주문
                      _buildOrderList(
                        _getFilteredOrders(_allOrders),
                        emptyMessage: AppLocalizations.of(context)!.translate('orders.empty.all'),
                      ),
                    ],
                  ),
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
              label: Text(AppLocalizations.of(context)!.translate('orders.button.refresh')),
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
              onTableManage: order.isTableOrder
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TableLayoutPage(database: widget.database),
                        ),
                      )
                  : null,
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
        title: Text(
          AppLocalizations.of(context)!.translate('orders.detail.title').replaceAll('{orderNumber}', order.orderNumber),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.orderType'), _orderTypeLabel(context, order.type)),
              _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.status'), _statusLabel(context, order.status, order.type)),
              _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.cookingStatus'), _cookingStatusLabel(context, order.cookingStatus)),
              _buildDetailRow(
                AppLocalizations.of(context)!.translate('orders.detail.totalAmount'),
                '₩${NumberFormat('#,###').format(order.totalAmount)}',
              ),
              _buildDetailRow(
                AppLocalizations.of(context)!.translate('orders.detail.orderTime'),
                DateFormat('MM/dd HH:mm').format(order.createdAt),
              ),
              
              if (order.customerName != null)
                _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.customerName'), order.customerName!),
              if (order.customerPhone != null)
                _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.contact'), order.customerPhone!),
              if (order.scheduledTime != null)
                _buildDetailRow(
                  AppLocalizations.of(context)!.translate('orders.detail.scheduledTime'),
                  DateFormat('MM/dd HH:mm').format(order.scheduledTime!),
                ),
              if (order.table != null)
                _buildDetailRow(
                  AppLocalizations.of(context)!.translate('orders.detail.table'),
                  '${order.table!['tableNumber'] ?? ''}',
                ),
              if (order.note != null)
                _buildDetailRow(AppLocalizations.of(context)!.translate('orders.detail.memo'), order.note!),
              
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(context)!.translate('orders.detail.items'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
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
            child: Text(AppLocalizations.of(context)!.translate('orders.button.close')),
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

  String _orderTypeLabel(BuildContext context, OrderType type) {
    switch (type) {
      case OrderType.TABLE:
        return AppLocalizations.of(context)!.translate('orders.type.table');
      case OrderType.TAKEOUT:
        return AppLocalizations.of(context)!.translate('orders.type.takeout');
      case OrderType.DELIVERY:
        return AppLocalizations.of(context)!.translate('orders.type.delivery');
    }
  }

  String _statusLabel(BuildContext context, UnifiedOrderStatus status, OrderType type) {
    switch (status) {
      case UnifiedOrderStatus.PENDING:
        return AppLocalizations.of(context)!.translate('orders.status.pending');
      case UnifiedOrderStatus.CONFIRMED:
        return AppLocalizations.of(context)!.translate('orders.status.confirmed');
      case UnifiedOrderStatus.COOKING:
        return AppLocalizations.of(context)!.translate('orders.status.cooking');
      case UnifiedOrderStatus.READY:
        return type == OrderType.TAKEOUT
            ? AppLocalizations.of(context)!.translate('orders.status.pickupReady')
            : AppLocalizations.of(context)!.translate('orders.status.serveReady');
      case UnifiedOrderStatus.SERVED:
        return AppLocalizations.of(context)!.translate('orders.status.served');
      case UnifiedOrderStatus.PICKED_UP:
        return AppLocalizations.of(context)!.translate('orders.status.pickedUp');
      case UnifiedOrderStatus.CANCELLED:
        return AppLocalizations.of(context)!.translate('orders.status.cancelled');
      case UnifiedOrderStatus.MODIFIED:
        return AppLocalizations.of(context)!.translate('orders.status.modified');
    }
  }

  String _cookingStatusLabel(BuildContext context, CookingStatus? status) {
    switch (status) {
      case CookingStatus.WAITING:
        return AppLocalizations.of(context)!.translate('orders.cookingStatus.waiting');
      case CookingStatus.IN_PROGRESS:
        return AppLocalizations.of(context)!.translate('orders.cookingStatus.inProgress');
      case CookingStatus.COMPLETED:
        return AppLocalizations.of(context)!.translate('orders.cookingStatus.completed');
      case null:
        return AppLocalizations.of(context)!.translate('orders.cookingStatus.unknown');
    }
  }
}
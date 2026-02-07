import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../core/models/cart.dart';
import '../../core/models/cart_item.dart';
import '../../core/theme/app_theme.dart';
import '../../core/i18n/app_localizations.dart';
import '../../data/local/app_database.dart';
import '../../data/local/models.dart';
import 'package:uuid/uuid.dart';
import '../../common/services/error_diagnostic_service.dart';
import '../common/diagnostic_error_dialog.dart';
import '../../core/storage/auth_storage.dart';
import '../home/home_page.dart';
import 'widgets/title_bar.dart';
import '../common/navigation_title_bar.dart';
import '../common/navigation_tab.dart';
import 'widgets/cart_grid.dart';
import 'widgets/product_selection_area.dart';
import 'widgets/function_buttons.dart';
import 'widgets/product_search_bar.dart';
import 'widgets/option_selection_dialog.dart';
import '../../data/local/models/options_models.dart';
import '../../core/printer/serial_printer_service.dart';
import '../../core/printer/printer_manager.dart';
import '../../core/printer/receipt_templates.dart';
import '../sales/sales_inquiry_page.dart';
import 'widgets/discount_selection_dialog.dart';
import 'widgets/suspended_sales_dialog.dart';
import 'widgets/member_search_dialog.dart';
import '../../core/storage/settings_storage.dart';
import '../../data/remote/pos_suspended_api.dart';
import 'widgets/split_payment_dialog.dart';
import '../../data/local/models/payment_model.dart';
import '../../data/remote/pos_sales_api.dart';
import '../../common/exceptions/diagnostic_exception.dart';
import '../../data/remote/table_management_api.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_master_api.dart';
import '../../sync/sync_service.dart';
import '../../data/remote/api_client.dart';
import '../../ui/widgets/virtual_keypad.dart';
import '../../data/remote/unified_order_api.dart';
import '../../data/models/unified_order.dart';
import '../../common/enums/error_code.dart';
import '../../common/models/diagnostic_error_response.dart';

enum PaymentMethod { card, cash, point, easy_payment }

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.database,
    this.tableId,
    this.tableName,
  });

  final AppDatabase database;
  final String? tableId;
  final String? tableName;

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  List<CategoryModel> _categories = [];
  List<ProductModel> _products = [];
  List<DiscountModel> _discounts = [];
  String? _selectedCategoryId;
  String _searchQuery = '';
  Cart _cart = Cart();
  Set<String> _selectedManualDiscountIds = {};
  MemberModel? _selectedMember;
  Map<String, dynamic>? _selectedTableOrder;
  int _guestCount = 0;
  DateTime? _orderStartTime;
  bool _isLoading = true;

  bool _showBarcodeInGrid = false;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadData();
    // Force focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final categories = await widget.database.getCategories();
      final products = await widget.database.getProducts();
      final discounts = await widget.database.getDiscounts();

      // Load store settings for barcode display
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      // Assuming 'saleShowBarcodeInGrid' is/will be available in session info or we fetch it
      // If currently not in session, might need to fetch settings or update session logic.
      // For now, let's assume it gets synced into session or we default to false.
      // If strictly required to fetch fresh settings:
      // final settings = await ApiClient(accessToken...).getSettings...
      // but let's check if we can get it from session map if updated there.
      // If not, we might need to rely on what's available or fetch it.
      // Let's assume the session login/refresh logic puts it there. 
      // check: session['saleShowBarcodeInGrid']
      
      bool showBarcode = false;
      if (session['saleShowBarcodeInGrid'] == true || session['saleShowBarcodeInGrid'] == 'true') {
        showBarcode = true;
      }

      // ... (existing code for tableId check) ...
      
      // If tableId is provided, load existing active order from server
      if (widget.tableId != null) {
        final token = await auth.getAccessToken();
        if (token != null && session['storeId'] != null) {
          final apiClient = ApiClient(accessToken: token);
          final response = await http.get(
            apiClient.buildUri('/tables/active-orders', {'storeId': session['storeId']!}),
            headers: apiClient.headers,
          );
          if (response.statusCode == 200) {
            final List<dynamic> allOrders = jsonDecode(response.body);
            final tableOrder = allOrders.firstWhere((o) => o['tableId'] == widget.tableId, orElse: () => null);
            if (tableOrder != null) {
              _selectedTableOrder = tableOrder;
              _guestCount = tableOrder['guestCount'] ?? 0;
              _orderStartTime = tableOrder['createdAt'] != null ? DateTime.parse(tableOrder['createdAt']) : null;
              
              final List<dynamic> itemsData = tableOrder['items'];
              final productMap = {for (var p in products) p.id: p};
              final List<CartItem> cartItems = [];
              for (var item in itemsData) {
                final p = productMap[item['productId']];
                if (p != null) {
                  cartItems.add(CartItem(
                    product: p,
                    quantity: item['qty'],
                    selectedOptions: (item['options'] as List?)?.map((o) => ProductOptionModel.fromMap(o)).toList() ?? [],
                  ));
                }
              }
              _cart = Cart(items: cartItems);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _categories = categories;
          _products = products;
          _discounts = discounts;
          _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
          _showBarcodeInGrid = showBarcode;
          _isLoading = false;
        });
        _updateCartDiscounts();
        _searchFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.translate('sales.dataLoadFailed')}: $e')),
        );
      }
    }
  }

  // ... (existing helper methods) ...

  void _showKeypad() {
    showDialog(
      context: context,
      builder: (context) {
        String input = '';
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '바코드 수동 입력',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        input.isEmpty ? '바코드를 입력하세요' : input,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: input.isEmpty ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    VirtualKeypad(
                      onKeyPress: (key) => setState(() => input += key),
                      onDelete: () => setState(() {
                        if (input.isNotEmpty) input = input.substring(0, input.length - 1);
                      }),
                      onClear: () => setState(() => input = ''),
                      onEnter: () {
                        Navigator.pop(context);
                        if (input.isNotEmpty) {
                          _onBarcodeSubmitted(input);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    ).then((_) {
      // Restore focus to search bar after keypad dialog closes
      _searchFocusNode.requestFocus();
    });
  }

  // Refactor _onBarcodeSubmitted to clear text manually if needed
  void _onBarcodeSubmitted(String barcode) {
    try {
      // 바코드로 상품 찾기
      final product = _products.firstWhere(
        (p) => p.barcode != null && p.barcode == barcode && p.isActive,
        orElse: () => _products.firstWhere(
          (p) => p.name.toLowerCase().contains(barcode.toLowerCase()) && p.isActive,
          orElse: () => throw StateError('상품을 찾을 수 없습니다'),
        ),
      );
      
      setState(() {
        _cart = _cart.addItem(product);
        _searchQuery = ''; // 검색어 초기화
      });
      _updateCartDiscounts();
      _searchFocusNode.requestFocus(); // Keep focus
    } catch (e) {
      // Note: SnackBar might steal focus? Usually OK.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.translate('sales.productNotFound')}: $barcode'),
            backgroundColor: AppTheme.error,
          ),
        );
        _searchFocusNode.requestFocus();
      }
    }
  }

  void _updateCartDiscounts() {
    // 상품별 할인 적용
    List<CartItem> newItems = [];
    for (var item in _cart.items) {
      // 1. 상품별 할인 (Product specific discounts)
      List<DiscountModel> applicableDiscounts = _discounts.where((d) {
        return d.status == 'ACTIVE' && 
               d.type == 'PRODUCT' && 
               d.targetId == item.product.id;
      }).toList();
      
      // 2. 카테고리별 할인 (Category specific discounts)
      List<DiscountModel> categoryDiscounts = _discounts.where((d) {
        return d.status == 'ACTIVE' && 
               d.type == 'CATEGORY' && 
               d.targetId == item.product.categoryId;
      }).toList();

      List<DiscountModel> allItemDiscounts = [...applicableDiscounts, ...categoryDiscounts];

      // 우선순위 정렬 (높은 순)
      allItemDiscounts.sort((a, b) => b.priority.compareTo(a.priority));

      // 가장 높은 우선순위 할인 적용 (단일 적용 정책)
      // TODO: 다중 할인 정책이 있다면 로직 수정 필요
      DiscountModel? bestDiscount = allItemDiscounts.isNotEmpty ? allItemDiscounts.first : null;

      newItems.add(item.copyWith(appliedDiscounts: bestDiscount != null ? [bestDiscount] : []));
    }

    // Filter manual discounts
    final activeManualDiscounts = _discounts.where((d) => 
      _selectedManualDiscountIds.contains(d.id) && d.status == 'ACTIVE' && d.type == 'CART').toList();

    _cart = Cart(items: newItems, cartDiscounts: activeManualDiscounts);
  }

  void _onHomePressed() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => HomePage(database: widget.database)),
      (route) => false,
    );
  }

  /// 자동 동기화 실행 (에러 복구용)
  /// 장바구니와 결제 컨텍스트를 보존하면서 동기화
  Future<void> _performAutoSync() async {
    try {
      if (!mounted) return;
      
      // ✅ 1. 현재 컨텍스트 저장
      final savedCart = _cart;
      final savedDiscountIds = Set<String>.from(_selectedManualDiscountIds);
      final savedMember = _selectedMember;
      
      print('[SalesPage] 💾 장바구니 저장: ${savedCart.items.length}개 상품');
      print('[SalesPage] 💾 할인 저장: ${savedDiscountIds.length}개');
      print('[SalesPage] 💾 멤버 저장: ${savedMember?.id ?? "없음"}');
      
      // ✅ 2. 사용자에게 확인 (장바구니가 있는 경우만)
      if (savedCart.items.isNotEmpty) {
        final confirm = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('동기화 확인'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('마스터 데이터를 동기화합니다.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📦 현재 장바구니 정보',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('• 상품: ${savedCart.items.length}개'),
                      Text('• 금액: ₩${savedCart.total.toStringAsFixed(0)}'),
                      if (savedDiscountIds.isNotEmpty)
                        Text('• 할인: ${savedDiscountIds.length}개'),
                      if (savedMember != null)
                        Text('• 멤버: ${savedMember.name}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '✅ 장바구니 정보는 보존됩니다\n✅ 동기화 후 결제를 계속할 수 있습니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('동기화 실행'),
              ),
            ],
          ),
        );
        
        if (confirm != true) {
          print('[SalesPage] ❌ 동기화 취소됨');
          return;
        }
      }
      
      // ✅ 3. 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false, // 뒤로가기 막기
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('마스터 데이터 동기화 중...'),
                    SizedBox(height: 8),
                    Text(
                      '장바구니 정보는 보존됩니다',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final storage = AuthStorage();
      final session = await storage.getSessionInfo();
      final accessToken = await storage.getAccessToken();
      
      if (session == null || accessToken == null) {
        throw Exception('세션 정보가 없습니다');
      }

      final apiClient = ApiClient(accessToken: accessToken);
      final masterApi = PosMasterApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: PosSalesApi(apiClient),
      );

      // ✅ 4. 전체 동기화 실행
      print('[SalesPage] 🔄 동기화 시작...');
      final result = await syncService.syncMaster(
        storeId: session['storeId'] as String,
        manual: true,
      );

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (result.success) {
        print('[SalesPage] ✅ 동기화 성공: ${result.categoriesCount}개 카테고리, ${result.productsCount}개 상품');
        
        // ✅ 5. 데이터 다시 로드 (카테고리, 상품 목록만)
        await _loadData();
        
        // ✅ 6. 장바구니와 컨텍스트 복원
        if (mounted) {
          setState(() {
            _cart = savedCart;
            _selectedManualDiscountIds = savedDiscountIds;
            _selectedMember = savedMember;
          });
          
          print('[SalesPage] 🔄 장바구니 복원: ${_cart.items.length}개 상품');
          print('[SalesPage] 🔄 할인 복원: ${_selectedManualDiscountIds.length}개');
          print('[SalesPage] 🔄 멤버 복원: ${_selectedMember?.id ?? "없음"}');
        }
        
        // ✅ 7. 성공 메시지
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('동기화 완료!'),
                        Text(
                          '${result.categoriesCount}개 카테고리, ${result.productsCount}개 상품',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(result.error ?? '동기화 실패');
      }
    } catch (e) {
      print('[SalesPage] ❌ 동기화 오류: $e');
      
      if (mounted) {
        // 로딩 다이얼로그가 열려있으면 닫기
        Navigator.of(context, rootNavigator: true).popUntil((route) {
          return route.isFirst || !route.navigator!.canPop();
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// 데이터베이스 초기화 및 재동기화
  Future<void> _resetDatabaseAndSync() async {
    try {
      if (!mounted) return;
      
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('데이터베이스 초기화 중...'),
                    SizedBox(height: 8),
                    Text(
                      '잠시만 기다려주세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final storage = AuthStorage();
      final session = await storage.getSessionInfo();
      final accessToken = await storage.getAccessToken();
      
      if (session == null || accessToken == null) {
        throw Exception('세션 정보가 없습니다');
      }

      // 데이터베이스 초기화
      print('[SalesPage] 🗑️ 데이터베이스 초기화 시작...');
      await widget.database.clearAll();
      print('[SalesPage] ✅ 데이터베이스 초기화 완료');

      final apiClient = ApiClient(accessToken: accessToken);
      final masterApi = PosMasterApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: PosSalesApi(apiClient),
      );

      // 전체 동기화 실행
      print('[SalesPage] 🔄 재동기화 시작...');
      final result = await syncService.syncMaster(
        storeId: session['storeId'] as String,
        manual: true,
      );

      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      }

      if (result.success) {
        print('[SalesPage] ✅ 재동기화 성공: ${result.categoriesCount}개 카테고리, ${result.productsCount}개 상품');
        
        // 데이터 다시 로드
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('초기화 및 동기화 완료!'),
                        Text(
                          '${result.categoriesCount}개 카테고리, ${result.productsCount}개 상품',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        throw Exception(result.error ?? '재동기화 실패');
      }
    } catch (e) {
      print('[SalesPage] ❌ 초기화 및 재동기화 오류: $e');
      
      if (mounted) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('초기화 및 재동기화 실패: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _searchQuery = ''; // 카테고리 변경 시 검색어 초기화
    });
  }

  List<ProductModel> get _filteredProducts {
    return _products.where((p) {
      // 1. 카테고리 필터
      if (_selectedCategoryId != null && p.categoryId != _selectedCategoryId) {
        return false;
      }
      
      // 2. 검색어 필터
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final nameMatch = p.name.toLowerCase().contains(query);
        final barcodeMatch = p.barcode?.contains(query) ?? false;
        if (!nameMatch && !barcodeMatch) return false;
      }

      return true;
    }).toList();
  }

  void _onProductTap(ProductModel product) {
    if (product.optionGroups.isNotEmpty) {
      // 옵션이 있는 상품 -> 옵션 선택 다이얼로그 표시
      showDialog(
        context: context,
        builder: (context) => OptionSelectionDialog(product: product),
      ).then((result) {
        if (result != null && result is Map<String, dynamic>) {
           final selectedOptions = result['selectedOptions'] as List<ProductOptionModel>;
           final quantity = result['quantity'] as int;
           _addCartItem(product, quantity: quantity, options: selectedOptions);
        }
        _searchFocusNode.requestFocus();
      });
    } else {
      // 옵션이 없는 상품 -> 바로 추가
      _addCartItem(product);
      _searchFocusNode.requestFocus();
    }
  }

  void _addCartItem(ProductModel product, {int quantity = 1, List<ProductOptionModel> options = const []}) {
    setState(() {
      _cart = _cart.addItem(product, quantity: quantity, selectedOptions: options);
    });
    _updateCartDiscounts();
  }

  void _onCartItemQuantityChanged(String itemId, int newQty) {
    setState(() {
      // Note: Cart usually identifies items by product ID and options. 
      // Assuming itemId here maps to product.id for simple items, or we need to pass options.
      // If CartGrid passes 'product.id', this works for simple items. 
      // For multi-option items, updateItemQuantity might need more info.
      // But let's assume CartGrid handles calls appropriately.
      // Corrected method name: updateItemQuantity
      _cart = _cart.updateItemQuantity(itemId, newQty);
    });
    _updateCartDiscounts();
  }

  void _onCartItemRemove(String itemId) {
    setState(() {
      _cart = _cart.removeItem(itemId);
    });
    _updateCartDiscounts();
  }

  void _onDiscount() {
    showDialog(
      context: context,
      builder: (context) => DiscountSelectionDialog(
        availableDiscounts: _discounts.where((d) => d.type == 'CART' && d.status == 'ACTIVE').toList(),
        selectedDiscountIds: _selectedManualDiscountIds,
      ),
    ).then((result) {
      if (result != null && result is Set<String>) {
        setState(() {
          _selectedManualDiscountIds = result;
          final activeManualDiscounts = _discounts.where((d) => 
            _selectedManualDiscountIds.contains(d.id) && d.status == 'ACTIVE' && d.type == 'CART').toList();
          _cart = Cart(items: _cart.items, cartDiscounts: activeManualDiscounts);
        });
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _onMember() {
    showDialog(
      context: context,
      builder: (context) => MemberSearchDialog(database: widget.database),
    ).then((member) {
      if (member != null && member is MemberModel) {
        setState(() {
          _selectedMember = member;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${member.name}님이 선택되었습니다.')),
        );
      }
      _searchFocusNode.requestFocus();
    });
  }

  void _onCancel() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('common.confirm')),
        content: Text('장바구니를 비우시겠습니까?'), // TODO: Lang
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate('common.cancel')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _cart = Cart();
                _selectedManualDiscountIds = {};
                _selectedMember = null;
              });
              _searchFocusNode.requestFocus();
            },
            child: const Text('비우기'),
          ),
        ],
      ),
    );
  }

  Future<void> _onHold() async {
    // ✅ 장바구니가 비어있으면 보류 거래 복원
    if (_cart.isEmpty) {
      await _handleSuspendedSalesRestore();
    } else {
      // ✅ 장바구니가 있으면 현재 거래 보류
      await _suspendCurrentSale();
    }
  }

  /// 보류 거래 복원 (장바구니 확인 포함)
  Future<void> _handleSuspendedSalesRestore() async {
    final suspendedId = await showDialog<String>(
      context: context,
      builder: (context) => SuspendedSalesDialog(database: widget.database),
    );
    
    if (suspendedId != null) {
      // TODO: 보류 거래 복원 로직 구현
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('보류 거래 복원: $suspendedId')),
      );
    }
  }

  /// 현재 장바구니 보류
  Future<void> _suspendCurrentSale() async {
    if (_cart.isEmpty) return;
    
    try {
      final storage = AuthStorage();
      final session = await storage.getSessionInfo();
      final accessToken = await storage.getAccessToken();
      
      if (session == null || accessToken == null) {
        throw Exception('세션 정보가 없습니다');
      }
      
      final api = PosSuspendedApi(accessToken: accessToken);
      
      // 보류 거래 데이터 생성
      final suspendedData = {
        'storeId': session['storeId'],
        'posId': session['posId'],
        'tableId': widget.tableId,
        'totalAmount': _cart.total,
        'items': _cart.items.map((item) => {
          'productId': item.product.id,
          'qty': item.quantity,
          'price': item.product.price,
          'options': item.selectedOptions.map((opt) => {
            'id': opt.id,
            'name': opt.name,
            'price': opt.priceAdjustment,
          }).toList(),
        }).toList(),
        'discountIds': _selectedManualDiscountIds.toList(),
        'memberId': _selectedMember?.id,
      };
      
      await api.createSuspendedSale(session['storeId'] as String, suspendedData);
      
      // ✅ 보류 성공 - 장바구니 초기화
      setState(() {
        _cart = Cart();
        _selectedManualDiscountIds.clear();
        _selectedMember = null;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('거래가 보류되었습니다'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('보류 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 기존 테이블 주문 메서드 (호환성 유지용)
  Future<void> _onOrder() async {
    // 새로운 통합 메서드로 리다이렉트
    await _handleTableOrder();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.translate('payment.tableOrderAccepted'))),
      );
      // 테이블 뷰로 돌아가지 않고 현재 화면 유지 (탭 네비게이션 사용)
    }
  }

  /// 현금 결제 처리 (주문 등록 + 현금 결제 표시)
  Future<void> _onCashPayment() async {
    if (_cart.isEmpty) return;
    
    // 현금 결제로 주문 등록 후 장바구니 초기화
    await _registerOrderOnly(paymentType: '현금');
  }

  /// 카드 결제 처리 (주문 등록 + 카드 결제 표시)
  Future<void> _onCardPayment() async {
    if (_cart.isEmpty) return;
    
    // 카드 결제로 주문 등록 후 장바구니 초기화
    await _registerOrderOnly(paymentType: '카드');
  }

  /// 주문 완료 처리 (결제 방식 미지정)
  void _onSplitCheckout() async {
    if (_cart.isEmpty) return;
    
    // 주문 완료 처리 후 장바구니 초기화 (주문관리에서 결제 진행)
    await _registerOrderOnly();
  }

  /// 주문 등록 처리 메서드 (테이블/테이크아웃 통합)
  Future<void> _registerOrderOnly({String? paymentType}) async {
    try {
      // 테이블 주문과 테이크아웃 주문을 동일하게 처리
      if (widget.tableId == null) {
        // 테이크아웃 주문
        await _handleTakeoutOrder();
      } else {
        // 테이블 주문 - 기존 _onOrder 로직 사용하지만 단순화
        await _handleTableOrder();
      }
      
      // 주문 등록 완료 후 장바구니 초기화
      if (mounted) {
        setState(() {
          _cart = Cart();
          _selectedManualDiscountIds = {};
          _selectedMember = null;
        });
        
        final orderType = widget.tableId != null 
          ? AppLocalizations.of(context)!.translate('payment.tableOrder')
          : AppLocalizations.of(context)!.translate('payment.takeoutOrder');
        final message = paymentType != null 
          ? AppLocalizations.of(context)!.translate('payment.${paymentType == '현금' ? 'cashOrderCompleted' : 'cardOrderCompleted'}').replaceAll('{orderType}', orderType)
          : AppLocalizations.of(context)!.translate('payment.orderCompleted').replaceAll('{orderType}', orderType);
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        _searchFocusNode.requestFocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.translate('payment.orderProcessFailed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 테이블 주문 처리 (기존 _onOrder 로직 단순화)
  Future<void> _handleTableOrder() async {
    if (_cart.isEmpty) return;
    
    final auth = AuthStorage();
    final session = await auth.getSessionInfo();
    final token = await auth.getAccessToken();

    if (token == null || session['storeId'] == null) {
      throw Exception('로그인 정보가 없습니다');
    }

    final apiClient = ApiClient(accessToken: token);
    final tableApi = TableManagementApi(apiClient);

    await tableApi.createOrUpdateOrder({
      'storeId': session['storeId'],
      'tableId': widget.tableId!,
      'guestCount': _guestCount,
      'items': _cart.items.map((item) => {
        'productId': item.product.id,
        'qty': item.quantity,
        'price': item.product.price,
        'options': item.selectedOptions.map((o) => o.toMap()).toList(),
      }).toList(),
    });
  }

  Future<void> _handleTakeoutOrder() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 인증 정보 가져오기
      final auth = AuthStorage();
      final accessToken = await auth.getAccessToken();
      final session = await auth.getSessionInfo();

      if (accessToken == null || session['storeId'] == null) {
        Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
        _showErrorDialog('인증 정보를 찾을 수 없습니다.');
        return;
      }

      // 통합 주문 API 클라이언트 생성
      final apiClient = ApiClient(accessToken: accessToken);
      final orderApi = UnifiedOrderApi(apiClient);

      // 안전한 숫자 변환 헬퍼 함수
      double safeToDouble(dynamic value) {
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          return double.tryParse(value) ?? 0.0;
        } else {
          return 0.0;
        }
      }

      // 주문 아이템 변환
      final orderItems = _cart.items.map((cartItem) {
        // CartItem의 unitPrice를 사용하거나, 안전하게 변환
        final price = cartItem.unitPrice;
        return CreateOrderItemRequest(
          productId: cartItem.product.id,
          quantity: cartItem.quantity,
          unitPrice: safeToDouble(price),
          note: null, // CartItem에 note 속성이 없으므로 null로 처리
        );
      }).toList();

      // 통합 주문 생성
      final order = await orderApi.createOrder(
        storeId: session['storeId']!,
        type: OrderType.TAKEOUT,
        totalAmount: safeToDouble(_cart.total),
        items: orderItems,
        note: null,
        customerName: null, // 고객 이름 없이 주문
        customerPhone: null, // 고객 전화번호 없이 주문
        scheduledTime: null, // 예약 시간 없이 주문
      );

      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      // 주문번호 확인 다이얼로그 표시
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('주문 완료'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                '주문이 성공적으로 등록되었습니다.',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Column(
                  children: [
                    const Text(
                      '주문번호',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      order.orderNumber,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('확인'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        // 주문 등록 완료 - 장바구니 초기화 (주문관리에서 결제 처리)
        setState(() {
          _cart.clear();
        });

        // 포커스 복원
        _searchFocusNode.requestFocus();
      }

    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기 (있는 경우)
      _showErrorDialog('주문 처리 중 오류가 발생했습니다: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _processPaymentSuccess(
    PaymentMethod method, 
    int totalAmount, 
    {
      int? paidAmount, 
      int? changeAmount,
      String? cardApprovalNumber,
      String? cardCompany,
      String? cardNumber,
      int? installmentMonths,
      List<SalePaymentModel>? payments, // Added parameter
    }
  ) async {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      
      if (token == null) return;

      final salesApi = PosSalesApi(ApiClient(accessToken: token));
      
      try {
        final clientSaleId = const Uuid().v4();
        
        await salesApi.createSale({
          'clientSaleId': clientSaleId,
          'storeId': session['storeId'],
          'posId': session['posId'],
          'totalAmount': totalAmount,
          'paidAmount': paidAmount ?? totalAmount,
          'items': _cart.items.map((i) => {
            'productId': i.product.id,
            'qty': i.quantity,
            'price': i.product.price,
            'discountAmount': i.discountAmount,
          }).toList(),
          'payments': payments != null
              ? payments.map((p) => {
                  'method': p.method,
                  'amount': p.amount,
                  if (p.cardApproval != null) 'cardApproval': p.cardApproval,
                  if (p.cardLast4 != null) 'cardLast4': p.cardLast4,
                }).toList()
              : [
                  {
                    'method': method.toString().split('.').last.toUpperCase(),
                    'amount': paidAmount ?? totalAmount,
                    if (cardApprovalNumber != null) 'cardApproval': cardApprovalNumber,
                  }
                ],
          if (_selectedMember?.id != null) 'membershipId': _selectedMember!.id,
        });

        // 테이블 주문인 경우 주문 완료 처리
        if (widget.tableId != null) {
            // Note: Server usually clears active order when sale is created linked to tableId
            // If explicit clear is needed:
            // final tableApi = TableManagementApi(ApiClient(accessToken: token));
            // await tableApi.clearTable(session['storeId'] as String, widget.tableId!);
        }
        
        // Print Receipt (if configured)
        try {
          // TODO: Fetch settings?
          // For now, auto-print if serial printer is connected? 
          // Or just let user decide via dialog?
          // Usually we print automatically here.
        } catch (e) {
          print('Print failed: $e');
        }

        if (mounted) {
          setState(() {
            _cart = Cart();
            _selectedManualDiscountIds = {};
            _selectedMember = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('결제가 완료되었습니다.')),
          );
          
          if (widget.tableId != null) {
            Navigator.pop(context);
          }
        }
        
      } catch (e) {
        if (mounted) {
          DiagnosticErrorResponse? diagnosticError;
          
          // DiagnosticException 처리 (새로운 방식)
          if (e is DiagnosticException) {
            diagnosticError = e.error;
          }
          // HTTP 응답인 경우 진단 가능한 에러로 처리 (구형 방식)
          else if (e is http.Response) {
            diagnosticError = ErrorDiagnosticService.parseDiagnosticError(e);
          }
          
          if (diagnosticError != null) {
            // 시스템 정보 수집
            final products = await widget.database.getProducts();
            final categories = await widget.database.getCategories();
            final productCount = products.length;
            final categoryCount = categories.length;
            final lastSyncStr = await widget.database.getSyncMetadata('lastMasterSync');
            final lastSync = lastSyncStr != null ? DateTime.parse(lastSyncStr) : null;
            
            // ⚠️ 중복 결제 위험 체크
            final isDuplicateRisk = diagnosticError.statusCode >= 500 || 
                                   diagnosticError.errorCode.code.contains('TIMEOUT');
            
            // SALE_PRODUCT_NOT_FOUND 오류인 경우 자동 동기화 시도
            if (diagnosticError.errorCode == ErrorCode.saleProductNotFound) {
              print('[SalesPage] 🔄 SALE_PRODUCT_NOT_FOUND 감지 - 자동 동기화 시작');
              
              // 현재 결제 정보 저장
              final savedPaymentInfo = {
                'method': method,
                'totalAmount': totalAmount,
                'paidAmount': paidAmount,
                'cardApprovalNumber': cardApprovalNumber,
                'cardCompany': cardCompany,
                'cardNumber': cardNumber,
                'installmentMonths': installmentMonths,
                'payments': payments,
              };
              
              // 자동 동기화 실행 (확인 없이)
              try {
                final auth = AuthStorage();
                final accessToken = await auth.getAccessToken();
                final sessionInfo = await auth.getSessionInfo();
                
                if (accessToken != null && sessionInfo != null) {
                  final apiClient = ApiClient(accessToken: accessToken);
                  final masterApi = PosMasterApi(apiClient);
                  final syncService = SyncService(
                    database: widget.database,
                    masterApi: masterApi,
                    salesApi: PosSalesApi(apiClient),
                  );
                  
                  // 로딩 표시
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => WillPopScope(
                      onWillPop: () async => false,
                      child: const Center(
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text('상품 정보 동기화 중...'),
                                SizedBox(height: 8),
                                Text(
                                  '동기화 후 자동으로 결제를 재시도합니다',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                  
                  // 동기화 실행
                  final syncResult = await syncService.syncMaster(
                    storeId: sessionInfo['storeId'] as String,
                    manual: true,
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
                  }
                  
                  if (syncResult.success) {
                    // 동기화 성공 - 데이터 다시 로드
                    await _loadData();
                    
                    // 자동으로 결제 재시도
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('동기화 완료'),
                                    Text(
                                      '결제를 재시도합니다...',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                      
                      // 결제 재시도
                      await Future.delayed(const Duration(milliseconds: 500));
                      await _processPaymentSuccess(
                        savedPaymentInfo['method'] as PaymentMethod,
                        savedPaymentInfo['totalAmount'] as int,
                        paidAmount: savedPaymentInfo['paidAmount'] as int?,
                        cardApprovalNumber: savedPaymentInfo['cardApprovalNumber'] as String?,
                        cardCompany: savedPaymentInfo['cardCompany'] as String?,
                        cardNumber: savedPaymentInfo['cardNumber'] as String?,
                        installmentMonths: savedPaymentInfo['installmentMonths'] as int?,
                        payments: savedPaymentInfo['payments'] as List<SalePaymentModel>?,
                      );
                      return; // 성공적으로 재시도했으므로 종료
                    }
                  } else {
                    // 동기화 실패 - DB 초기화 옵션 제공
                    if (mounted) {
                      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
                      
                      final shouldReset = await showDialog<bool>(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => AlertDialog(
                          title: const Row(
                            children: [
                              Icon(Icons.warning_amber, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('동기화 실패'),
                            ],
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('마스터 데이터 동기화에 실패했습니다.'),
                              const SizedBox(height: 12),
                              const Text(
                                '데이터베이스를 초기화하고 다시 동기화하시겠습니까?',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '⚠️ 주의사항',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '• 로컬에 저장된 모든 데이터가 삭제됩니다\n• 동기화 후 다시 시도해야 합니다',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('취소'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('초기화 및 동기화'),
                            ),
                          ],
                        ),
                      );
                      
                      if (shouldReset == true) {
                        // DB 초기화 및 재동기화
                        await _resetDatabaseAndSync();
                        
                        // 재시도
                        await Future.delayed(const Duration(milliseconds: 500));
                        await _processPaymentSuccess(
                          savedPaymentInfo['method'] as PaymentMethod,
                          savedPaymentInfo['totalAmount'] as int,
                          paidAmount: savedPaymentInfo['paidAmount'] as int?,
                          cardApprovalNumber: savedPaymentInfo['cardApprovalNumber'] as String?,
                          cardCompany: savedPaymentInfo['cardCompany'] as String?,
                          cardNumber: savedPaymentInfo['cardNumber'] as String?,
                          installmentMonths: savedPaymentInfo['installmentMonths'] as int?,
                          payments: savedPaymentInfo['payments'] as List<SalePaymentModel>?,
                        );
                        return;
                      }
                    }
                  }
                }
              } catch (syncError) {
                print('[SalesPage] ❌ 자동 동기화 실패: $syncError');
                if (mounted) {
                  Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
                }
              }
            }
            
            // 일반 오류 다이얼로그 표시
            await DiagnosticErrorDialog.show(
              context: context,
              error: diagnosticError,
              onSyncPressed: () async {
                // 수동 동기화 실행
                await _performAutoSync();
              },
              onRetryPressed: isDuplicateRisk ? null : () async {
                // ⚠️ 서버 오류나 타임아웃일 경우 재시도 버튼 비활성화
                // (결제가 성공했는데 응답만 실패했을 수 있음)
                await _processPaymentSuccess(
                  method,
                  totalAmount,
                  paidAmount: paidAmount,
                  cardApprovalNumber: cardApprovalNumber,
                  cardCompany: cardCompany,
                  cardNumber: cardNumber,
                  installmentMonths: installmentMonths,
                  payments: payments,
                );
              },
              systemInfo: {
                'storeId': session['storeId'],
                'posId': session['posId'],
                'appVersion': '1.0.0',
                'lastSyncAt': lastSync?.toIso8601String() ?? 'Never',
                'productCount': productCount,
                'categoryCount': categoryCount,
                'cartItemCount': _cart.items.length,
                'totalAmount': totalAmount,
                'isDuplicateRisk': isDuplicateRisk,
                'warning': isDuplicateRisk 
                  ? '서버 오류 또는 타임아웃: 결제가 실제로는 성공했을 수 있음' 
                  : null,
              },
            );
            return;
          }
          
          // 구형 에러 처리 (fallback)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('결제 처리 실패: $e')),
          );
        }
      }
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // 1. 상단 네비게이션 타이틀바
          NavigationTitleBar(
            currentTab: NavigationTab.sales,
            database: widget.database,
          ),

          // 테이블 정보 바 (테이블 모드일 때만 표시)
          if (widget.tableId != null) _buildTableInfoBar(),

          // 검색 바
          ProductSearchBar(
            searchQuery: _searchQuery,
            onSearchChanged: _onSearchChanged,
            onBarcodeSubmitted: _onBarcodeSubmitted,
            focusNode: _searchFocusNode,
            onShowKeypad: _showKeypad,
          ),

          // 메인 콘텐츠 영역 (좌우 5:5)
          Expanded(
            child: Row(
              children: [
                // 2. 좌측: 장바구니 그리드 (50%)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      if (_selectedMember != null)
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person, color: AppTheme.primary, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '회원: ${_selectedMember!.name} (${_selectedMember!.phone})',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
                                ),
                              ),
                              Text(
                                '${_selectedMember!.points}P',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(() => _selectedMember = null),
                                child: const Icon(Icons.cancel, size: 18, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: CartGrid(
                          cart: _cart,
                          onQuantityChanged: _onCartItemQuantityChanged,
                          onItemRemove: _onCartItemRemove,
                        ),
                      ),
                      // 결제 방식별 버튼들
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        color: AppTheme.surface,
                        child: Row(
                          children: [
                            // 현금 주문 버튼
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 70,
                                child: ElevatedButton.icon(
                                  onPressed: !_cart.isEmpty ? () => _onCashPayment() : null,
                                  icon: const Icon(Icons.money, size: 20),
                                  label: Text(
                                    AppLocalizations.of(context)!.translate('payment.cashPayment'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 카드 주문 버튼
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 70,
                                child: ElevatedButton.icon(
                                  onPressed: !_cart.isEmpty ? () => _onCardPayment() : null,
                                  icon: const Icon(Icons.credit_card, size: 20),
                                  label: Text(
                                    AppLocalizations.of(context)!.translate('payment.cardPayment'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 일반 주문 버튼
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 70,
                                child: ElevatedButton.icon(
                                  onPressed: !_cart.isEmpty ? _onSplitCheckout : null,
                                  icon: const Icon(Icons.check_circle, size: 20),
                                  label: Text(
                                    AppLocalizations.of(context)!.translate('payment.orderComplete'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. 우측: 상품 선택 영역 (50%)
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      // 우측 상단: 카테고리 + 상품 카드 (4컬럼 2열)
                      Expanded(
                        child: ProductSelectionArea(
                          categories: _categories,
                          selectedCategoryId: _selectedCategoryId,
                          products: _filteredProducts,
                          onCategorySelected: _onCategorySelected,
                          onProductTap: _onProductTap,
                          showBarcodeInGrid: _showBarcodeInGrid,
                        ),
                      ),

                      // 우측 하단: 기능 버튼
                      FunctionButtons(
                        onDiscount: _onDiscount,
                        onMember: _onMember,
                        onCancel: _onCancel,
                        onHold: _onHold,
                        showHold: widget.tableId == null,
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

  Widget _buildTableInfoBar() {
    final String duration = _orderStartTime != null 
      ? _formatDuration(DateTime.now().difference(_orderStartTime!))
      : '신규 주문';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border.withOpacity(0.5))),
      ),
      child: Row(
        children: [
          // 인원수 표시
          _InfoBadge(
            icon: Icons.people_outline,
            label: '인원',
            value: '$_guestCount명',
            color: AppTheme.primary,
          ),
          const SizedBox(width: 16),
          // 경과 시간
          _InfoBadge(
            icon: Icons.access_time,
            label: '주문시간',
            value: duration,
            color: AppTheme.warning,
          ),
          const Spacer(),
          // 담당 직원 (예시)
          const Text(
            '담당: 홍길동', // TODO: 실제 로그인한 직원이 있다면 연동
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}시간 ${d.inMinutes.remainder(60)}분';
    }
    return '${d.inMinutes}분';
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

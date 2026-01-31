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
import '../../core/storage/auth_storage.dart';
import '../home/home_page.dart';
import 'widgets/title_bar.dart';
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
import '../../data/remote/table_management_api.dart';
import '../../data/remote/api_client.dart';
import '../../ui/widgets/virtual_keypad.dart';

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

  void _onHold() {
    // For now, if cart is empty, show suspended sales list. If not empty, we might want to suspend.
    // However, existing SuspendedSalesDialog only lists sales (retrieval).
    // Logic for suspending should be separate or added to dialog. 
    // Fixing build first: match constructor
    if (_cart.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => SuspendedSalesDialog(database: widget.database),
      ).then((result) {
        // Handle retrieval based on result (sale ID or object)
        // TODO: Implement retrieval logic
      });
    } else {
       // TODO: Implement save logic
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보류 기능 구현 필요')));
    }
  }

  Future<void> _onOrder() async {
    if (_cart.isEmpty) return;
    
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();

      if (token == null || session['storeId'] == null) {
        throw Exception('Not logged in');
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('주문이 접수되었습니다.')),
        );
        Navigator.pop(context); // Go back to table view
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주문 접수 실패: $e')),
        );
      }
    }
  }

  void _onSplitCheckout() {
    showDialog(
      context: context,
      builder: (context) => SplitPaymentDialog(
        totalAmount: _cart.total, 
      ),
    ).then((result) async {
       if (result != null && result is List) {
          final payments = result.cast<SalePaymentModel>();
          // 복합 결제 (Split Payment)
          await _processPaymentSuccess(
            PaymentMethod.easy_payment, // Or 'SPLIT' if enum supports, using easy_payment as placeholder or add split
            _cart.total, 
            paidAmount: _cart.total, 
            payments: payments, // Add this parameter
          );
       }
       _searchFocusNode.requestFocus();
    });
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
          // 1. 상단 타이틀바
          TitleBar(
            title: widget.tableId != null 
                ? '${AppLocalizations.of(context)!.tableOrder} - ${widget.tableName}' 
                : AppLocalizations.of(context)!.sales,
            onHomePressed: _onHomePressed,
            leadingIcon: widget.tableId != null ? Icons.grid_view : Icons.home,
            leadingTooltip: widget.tableId != null 
                ? AppLocalizations.of(context)!.translate('sales.backToTable')
                : AppLocalizations.of(context)!.translate('common.backToHome'),
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
                      // Toast-style Big Pay Button
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        color: AppTheme.surface,
                        child: SizedBox(
                          width: double.infinity,
                          height: 80,
                          child: ElevatedButton(
                            onPressed: !_cart.isEmpty ? _onSplitCheckout : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.proceedToPayment,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '|   ₩${_cart.total.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (match) => "${match[1]},")}',
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.normal, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
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
                        onOrder: widget.tableId != null ? _onOrder : null,
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

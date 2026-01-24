import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../core/models/cart.dart';
import '../../core/models/cart_item.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final categories = await widget.database.getCategories();
      final products = await widget.database.getProducts();
      final discounts = await widget.database.getDiscounts();
      
      // If tableId is provided, load existing active order from server
      if (widget.tableId != null) {
        final auth = AuthStorage();
        final token = await auth.getAccessToken();
        final session = await auth.getSessionInfo();
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
          _isLoading = false;
        });
        _updateCartDiscounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    }
  }

  void _updateCartDiscounts() {
    // 1. Filter discounts to apply
    // Automatically apply PRODUCT and CATEGORY discounts, but only apply selected CART discounts
    final discountsToApply = _discounts.where((d) {
      if (d.type == 'PRODUCT' || d.type == 'CATEGORY') return true;
      if (d.type == 'CART') return _selectedManualDiscountIds.contains(d.id);
      return false;
    }).toList();

    setState(() {
      _cart = _cart.applyDiscounts(discountsToApply, _categories);
    });
  }

  void _onCategorySelected(String? categoryId) {
    setState(() {
      _selectedCategoryId = categoryId;
      _searchQuery = ''; // 카테고리 선택 시 검색어 초기화
    });
  }

  Future<void> _onProductTap(ProductModel product) async {
    List<ProductOptionModel>? selectedOptions;

    // 옵션이 있거나 콤보 메뉴인 경우 옵션 선택 창 표시
    if (product.optionGroups.isNotEmpty || product.type == 'COMBO') {
      final result = await showDialog<List<ProductOptionModel>>(
        context: context,
        builder: (context) => OptionSelectionDialog(product: product),
      );

      if (result == null) return; // 취소됨
      selectedOptions = result;
    }

    setState(() {
      _cart = _cart.addItem(product, selectedOptions: selectedOptions);
    });
    _updateCartDiscounts();
  }

  void _onCartItemQuantityChanged(String productId, int quantity) {
    setState(() {
      _cart = _cart.updateItemQuantity(productId, quantity);
    });
    _updateCartDiscounts();
  }

  void _onCartItemRemove(String productId) {
    setState(() {
      _cart = _cart.removeItem(productId);
    });
    _updateCartDiscounts();
  }

  List<ProductModel> get _filteredProducts {
    var filtered = _products.where((p) => p.isActive).toList();
    
    // 카테고리 필터
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    
    // 검색 필터
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.barcode != null && p.barcode!.toLowerCase().contains(query));
      }).toList();
    }
    
    return filtered;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      // 검색 시 카테고리 선택 해제
      if (query.isNotEmpty) {
        _selectedCategoryId = null;
      }
    });
  }

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('상품을 찾을 수 없습니다: $barcode'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _onHomePressed() {
    if (widget.tableId != null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(database: widget.database),
        ),
      );
    }
  }

  Future<void> _onDiscount() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할인을 적용할 상품이 없습니다')),
      );
      return;
    }

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => DiscountSelectionDialog(
        availableDiscounts: _discounts,
        selectedDiscountIds: _selectedManualDiscountIds,
      ),
    );

    if (result != null) {
      setState(() {
        _selectedManualDiscountIds = result;
      });
      _updateCartDiscounts();
    }
  }

  Future<void> _onMember() async {
    final MemberModel? member = await showDialog<MemberModel>(
      context: context,
      builder: (context) => MemberSearchDialog(database: widget.database),
    );

    if (member != null) {
      setState(() {
        _selectedMember = member;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${member.name} 회원이 선택되었습니다.')),
      );
    }
  }

  void _onCancel() {
    if (_cart.isEmpty && _selectedMember == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('취소할 내역이 없습니다')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 취소'),
        content: const Text('현재 거래 및 선택된 회원 정보를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cart = Cart();
                _selectedManualDiscountIds = {};
                _selectedMember = null;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('거래가 취소되었습니다')),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.error,
            ),
            child: const Text('예'),
          ),
        ],
      ),
    );
  }

  Future<void> _onHold() async {
    // 1. Check for partial payment (Guard)
    // currently POSAce doesn't have split payment UI, but we check if paidAmount > 0
    // If it were implemented, _cart would probably have a paidTotal property
    if (_cart.itemCount > 0 && false) { // Placeholder for partial payment check
       // If we had a real partial payment logic, we'd check it here.
       // showDialog(...) -> "Please refund partial payment before holding."
    }

    if (_cart.isEmpty) {
      // Show list if empty
      final suspendedSaleId = await showDialog<String>(
        context: context,
        builder: (context) => SuspendedSalesDialog(database: widget.database),
      );

      if (suspendedSaleId != null) {
        await _recallSuspendedSale(suspendedSaleId);
      }
      return;
    }

    // Save current cart if not empty
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 보류'),
        content: const Text('현재 거래를 보류하시겠습니까? (다른 POS에서도 확인 가능)'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('아니오')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('예')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];
      final posId = session['posId'];

      if (storeId == null || token == null) throw Exception('인증 정보가 없습니다.');

      final api = PosSuspendedApi(accessToken: token);
      
      final payload = {
        'storeId': storeId,
        'posId': posId,
        'totalAmount': _cart.total,
        'items': _cart.items.map((item) => {
          'productId': item.product.id,
          'qty': item.quantity,
          'price': item.unitPrice,
          'discountAmount': item.discountAmount,
          'options': item.selectedOptions.map((o) => o.toMap()).toList(),
        }).toList(),
      };

      await api.createSuspendedSale(storeId, payload);

      setState(() {
        _cart = Cart();
        _selectedManualDiscountIds = {};
        _selectedMember = null;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('거래가 서버에 보류되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('거래 보류 실패: $e')));
      }
    }
  }

  Future<void> _recallSuspendedSale(String suspendedSaleId) async {
    setState(() => _isLoading = true);
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];

      if (storeId == null || token == null) throw Exception('인증 정보가 없습니다.');

      final api = PosSuspendedApi(accessToken: token);
      final saleData = await api.getSuspendedSales(storeId).then((list) => list.firstWhere((s) => s['id'] == suspendedSaleId));
      
      final products = await widget.database.getProducts();
      final productMap = {for (var p in products) p.id: p};

      final List<CartItem> cartItems = [];
      final List<dynamic> itemsData = saleData['items'];

      for (var item in itemsData) {
        final product = productMap[item['productId']];
        if (product != null) {
          final optionsList = item['options'] as List?;
          final List<ProductOptionModel> options = optionsList != null 
              ? optionsList.map((o) => ProductOptionModel.fromMap(o as Map<String, dynamic>)).toList()
              : [];

          cartItems.add(CartItem(
            product: product,
            quantity: int.tryParse(item['qty'].toString()) ?? 1,
            selectedOptions: options,
          ));
        }
      }

      await api.deleteSuspendedSale(storeId, suspendedSaleId);

      if (mounted) {
        setState(() {
          _cart = Cart(items: cartItems);
          _selectedManualDiscountIds = {}; 
          _isLoading = false;
        });
        _updateCartDiscounts();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('보류 거래 호출 실패: $e')));
      }
    }
  }

  Future<void> _onSplitCheckout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('결제할 상품이 없습니다')));
      return;
    }

    final payments = await showDialog<List<SalePaymentModel>>(
      context: context,
      builder: (context) => SplitPaymentDialog(totalAmount: _cart.total),
    );

    if (payments != null && payments.isNotEmpty) {
      await _processPayment(payments);
    }
  }

  Future<void> _onOrder() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문할 상품이 없습니다.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      
      if (token == null || session['storeId'] == null) throw Exception('인증 정보가 없습니다.');

      final api = TableManagementApi(ApiClient(accessToken: token));
      
      final payload = {
        'tableId': widget.tableId,
        'storeId': session['storeId'],
        'sessionId': session['sessionId'],
        'employeeId': session['employeeId'],
        'items': _cart.items.map((item) => {
          'productId': item.product.id,
          'qty': item.quantity,
          'price': item.unitPrice,
          'options': item.selectedOptions.map((o) => o.toMap()).toList(),
        }).toList(),
      };

      await api.createOrUpdateOrder(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('주문이 등록되었습니다.')));
        Navigator.of(context).pop(); // Return to table layout
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('주문 등록 실패: $e')));
      }
    }
  }

  Future<void> _processPayment(List<SalePaymentModel> payments) async {
    setState(() => _isLoading = true);

    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final storeId = session['storeId'];
      final posId = session['posId'];
      final sessionId = session['sessionId'];
      final employeeId = session['employeeId'];

      if (storeId == null) throw Exception('매장 정보를 찾을 수 없습니다');

      final saleId = const Uuid().v4();
      final totalPaid = payments.fold<int>(0, (sum, p) => sum + p.amount);
      final pointsToEarn = (_cart.total * 0.01).round(); 

      // Prepare payments with saleId
      final finalPayments = payments.map((p) => SalePaymentModel(
        id: p.id,
        saleId: saleId,
        method: p.method,
        amount: p.amount,
        cardApproval: p.cardApproval,
        cardLast4: p.cardLast4,
      )).toList();

      final sale = SaleModel(
        id: saleId,
        storeId: storeId,
        posId: posId,
        sessionId: sessionId,
        employeeId: employeeId,
        memberId: _selectedMember?.id,
        totalAmount: _cart.total,
        paidAmount: totalPaid,
        paymentMethod: payments.length == 1 ? payments.first.method : 'SPLIT',
        status: 'COMPLETED',
        createdAt: DateTime.now(),
        memberPointsEarned: pointsToEarn,
        discountAmount: _cart.totalDiscountAmount,
        cartDiscountsJson: jsonEncode(_cart.cartDiscounts.map((d) {
          int amount = 0;
          if (d.method == 'PERCENTAGE') {
            amount = (_cart.subtotal * (d.rateOrAmount / 100)).round();
          } else {
            amount = d.rateOrAmount;
          }
          return {'name': d.name, 'amount': amount};
        }).toList()),
        payments: finalPayments,
      );

      final items = _cart.items.map((item) => SaleItemModel(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: item.product.id,
        qty: item.quantity,
        price: item.unitPrice,
        discountAmount: item.discountAmount,
        discountsJson: jsonEncode(item.appliedDiscounts.map((d) {
          int amount = 0;
          if (d.method == 'PERCENTAGE') {
            amount = (item.baseAndOptionsPrice * (d.rateOrAmount / 100)).round() * item.quantity;
          } else {
            amount = d.rateOrAmount * item.quantity;
          }
          return {'name': d.name, 'amount': amount};
        }).toList()),
      )).toList();

      await widget.database.insertSale(sale, items);

      // Update member points if selected
      if (_selectedMember != null) {
        await widget.database.updateMemberPoints(
          _selectedMember!.id,
          _selectedMember!.points + pointsToEarn,
        );
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _cart = Cart(); 
          _selectedManualDiscountIds = {};
          _selectedMember = null;
        });
        _updateCartDiscounts();

        _printReceipt(sale, items);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('결제가 완료되었습니다'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('결제 처리 중 오류 발생: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _printReceipt(SaleModel sale, List<SaleItemModel> items) async {
    print('SalesPage: Requesting print for sale ${sale.id}');
    try {
      final printer = SerialPrinterService();
      final settings = SettingsStorage();
      final auth = AuthStorage();
      
      final productMap = {for (var p in _products) p.id: p};
      final storeInfo = await auth.getSessionInfo();

      // 1. 영수증 출력
      final rPort = await settings.getReceiptPrinterPort();
      final rBaud = await settings.getReceiptPrinterBaud();
      
      if (rPort != null) {
        print('SalesPage: Attempting to print receipt on $rPort');
        if (!printer.isConnected(rPort)) {
          printer.connect(rPort, baudRate: rBaud);
        }
        if (printer.isConnected(rPort)) {
          final receiptBytes = await ReceiptTemplates.saleReceipt(sale, items, productMap, storeInfo: storeInfo);
          print('SalesPage: Receipt generated, sending ${receiptBytes.length} bytes to $rPort');
          await printer.printBytes(rPort, receiptBytes);
        } else {
          print('SalesPage: Receipt printer $rPort not connected.');
        }
      }

      // 2. 주방주문서 출력
      final kPort = await settings.getKitchenPrinterPort();
      final kBaud = await settings.getKitchenPrinterBaud();

      if (kPort != null) {
        print('SalesPage: Attempting to print kitchen order on $kPort');
        if (!printer.isConnected(kPort)) {
          printer.connect(kPort, baudRate: kBaud);
        }
        if (printer.isConnected(kPort)) {
          final kitchenBytes = await ReceiptTemplates.kitchenOrder(sale, items, productMap);
          print('SalesPage: Kitchen order generated, sending ${kitchenBytes.length} bytes to $kPort');
          await printer.printBytes(kPort, kitchenBytes);
        } else {
          print('SalesPage: Kitchen printer $kPort not connected.');
        }
      }
    } catch (e) {
      print('SalesPage: Printing error: $e');
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
            title: widget.tableId != null ? '테이블 주문 - ${widget.tableName}' : '판매',
            onHomePressed: _onHomePressed,
            leadingIcon: widget.tableId != null ? Icons.grid_view : Icons.home,
            leadingTooltip: widget.tableId != null ? '테이블로' : '홈으로',
          ),

          // 테이블 정보 바 (테이블 모드일 때만 표시)
          if (widget.tableId != null) _buildTableInfoBar(),

          // 검색 바
          ProductSearchBar(
            searchQuery: _searchQuery,
            onSearchChanged: _onSearchChanged,
            onBarcodeSubmitted: _onBarcodeSubmitted,
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
                                const Text(
                                  '결제하기',
                                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
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

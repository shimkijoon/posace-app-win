import 'dart:typed_data';
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
import '../../core/storage/settings_storage.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({
    super.key,
    required this.database,
  });

  final AppDatabase database;

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
      
      // 할인 적용
      final cartWithDiscounts = _cart.applyDiscounts(discounts);
      
      if (mounted) {
        setState(() {
          _categories = categories;
          _products = products;
          _discounts = discounts;
          _selectedCategoryId = categories.isNotEmpty ? categories.first.id : null;
          _cart = cartWithDiscounts;
          _isLoading = false;
        });
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
      _cart = _cart.applyDiscounts(_discounts);
    });
  }

  void _onCartItemQuantityChanged(String productId, int quantity) {
    setState(() {
      _cart = _cart.updateItemQuantity(productId, quantity);
      _cart = _cart.applyDiscounts(_discounts);
    });
  }

  void _onCartItemRemove(String productId) {
    setState(() {
      _cart = _cart.removeItem(productId);
      _cart = _cart.applyDiscounts(_discounts);
    });
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
        _cart = _cart.applyDiscounts(_discounts);
        _searchQuery = ''; // 검색어 초기화
      });
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
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(database: widget.database),
      ),
    );
  }

  void _onDiscount() {
    // TODO: 할인 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('할인 기능은 다음 단계에서 구현됩니다')),
    );
  }

  void _onMember() {
    // TODO: 회원 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원 기능은 다음 단계에서 구현됩니다')),
    );
  }

  void _onCancel() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('취소할 거래가 없습니다')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('거래 취소'),
        content: const Text('현재 거래를 취소하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cart = Cart();
                _cart = _cart.applyDiscounts(_discounts);
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

  void _onHold() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('보류할 거래가 없습니다')),
      );
      return;
    }

    // TODO: 거래 보류 기능 구현
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('거래 보류 기능은 다음 단계에서 구현됩니다')),
    );
  }

  Future<void> _onCheckout() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제할 상품이 없습니다')),
      );
      return;
    }

    // 결제 수단 선택 다이얼로그
    final String? method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('결제 수단 선택'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('현금 (CASH)'),
              onTap: () => Navigator.pop(context, 'CASH'),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('카드 (CARD)'),
              onTap: () => Navigator.pop(context, 'CARD'),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    await _processPayment(method);
  }

  Future<void> _processPayment(String method) async {
    setState(() => _isLoading = true);

    try {
      final session = await AuthStorage().getSessionInfo();
      final storeId = session['storeId'];
      final posId = session['posId'];

      if (storeId == null) throw Exception('매장 정보를 찾을 수 없습니다');

      final saleId = const Uuid().v4();
      final sale = SaleModel(
        id: saleId,
        storeId: storeId,
        posId: posId,
        totalAmount: _cart.total,
        paidAmount: _cart.total,
        paymentMethod: method,
        status: 'COMPLETED',
        createdAt: DateTime.now(),
      );

      final items = _cart.items.map((item) => SaleItemModel(
        id: const Uuid().v4(),
        saleId: saleId,
        productId: item.product.id,
        qty: item.quantity,
        price: item.unitPrice,
        discountAmount: item.discountAmount,
      )).toList();

      await widget.database.insertSale(sale, items);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _cart = Cart(); // 장바구니 초기화
          _cart = _cart.applyDiscounts(_discounts);
        });

        // 영수증 출력
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
            title: '판매',
            onHomePressed: _onHomePressed,
          ),

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
                  child: CartGrid(
                    cart: _cart,
                    onQuantityChanged: _onCartItemQuantityChanged,
                    onItemRemove: _onCartItemRemove,
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

                      // 우측 하단: 기능 버튼 + 결제 버튼
                      FunctionButtons(
                        onDiscount: _onDiscount,
                        onMember: _onMember,
                        onCancel: _onCancel,
                        onHold: _onHold,
                        onCheckout: _onCheckout,
                        isCheckoutEnabled: !_cart.isEmpty,
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
}

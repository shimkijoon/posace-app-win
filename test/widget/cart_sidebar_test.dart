import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:posace_app_win/core/models/cart.dart';
import 'package:posace_app_win/core/models/cart_item.dart';
import 'package:posace_app_win/core/i18n/app_localizations.dart';
import 'package:posace_app_win/ui/sales/widgets/cart_sidebar.dart';
import '../helpers/test_fixtures.dart';

Finder findTextContaining(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is Text) {
      final data = widget.data ?? widget.textSpan?.toPlainText() ?? '';
      return data.contains(text);
    }
    if (widget is RichText) {
      return widget.text.toPlainText().contains(text);
    }
    return false;
  });
}

void main() {
  group('CartSidebar Widget', () {
    late Cart emptyCart;
    late Cart cartWithItems;

    setUp(() {
      emptyCart = Cart.empty();

      final product1 = createProduct(id: 'p1', name: 'Americano', price: 5500);
      final product2 = createProduct(id: 'p2', name: 'Latte', price: 6500);

      cartWithItems = Cart(items: [
        CartItem(product: product1, quantity: 2),
        CartItem(product: product2, quantity: 1),
      ]);
    });

    Widget createTestWidget(Cart cart) {
      return MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cart,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) {},
            onClear: () {},
            onCheckout: () {},
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      );
    }

    testWidgets('should display empty state when cart is empty', (tester) async {
      await tester.pumpWidget(createTestWidget(emptyCart));
      await tester.pumpAndSettle();

      expect(findTextContaining('장바구니가 비어있습니다'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    });

    testWidgets('should display cart header', (tester) async {
      await tester.pumpWidget(createTestWidget(emptyCart));
      await tester.pumpAndSettle();

      expect(findTextContaining('장바구니'), findsOneWidget);
    });

    testWidgets('should not show clear button when cart is empty', (tester) async {
      await tester.pumpWidget(createTestWidget(emptyCart));
      await tester.pumpAndSettle();

      expect(findTextContaining('비우기'), findsNothing);
    });

    testWidgets('should show clear button when cart has items', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      expect(findTextContaining('비우기'), findsOneWidget);
    });

    testWidgets('should display product names in cart', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      expect(findTextContaining('Americano'), findsOneWidget);
      expect(findTextContaining('Latte'), findsOneWidget);
    });

    testWidgets('should display checkout button when cart has items', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      expect(findTextContaining('결제하기'), findsOneWidget);
      expect(find.byIcon(Icons.payment), findsOneWidget);
    });

    testWidgets('should not display checkout button when cart is empty', (tester) async {
      await tester.pumpWidget(createTestWidget(emptyCart));
      await tester.pumpAndSettle();

      expect(findTextContaining('결제하기'), findsNothing);
    });

    testWidgets('should display total amount', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      // Total: 5500 * 2 + 6500 * 1 = 17500
      expect(findTextContaining('총액'), findsOneWidget);
    });

    testWidgets('should have quantity controls for each item', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      // Each item has + and - buttons
      expect(find.byIcon(Icons.add), findsNWidgets(2));
      expect(find.byIcon(Icons.remove), findsNWidgets(2));
    });

    testWidgets('should have remove button for each item', (tester) async {
      await tester.pumpWidget(createTestWidget(cartWithItems));
      await tester.pumpAndSettle();

      // Each item has a close (remove) button
      expect(find.byIcon(Icons.close), findsNWidgets(2));
    });

    testWidgets('should call onClear when clear button is tapped', (tester) async {
      var clearCalled = false;

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cartWithItems,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) {},
            onClear: () => clearCalled = true,
            onCheckout: () {},
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(findTextContaining('비우기'));
      await tester.pump();

      expect(clearCalled, true);
    });

    testWidgets('should call onCheckout when checkout button is tapped', (tester) async {
      var checkoutCalled = false;

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cartWithItems,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) {},
            onClear: () {},
            onCheckout: () => checkoutCalled = true,
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(findTextContaining('결제하기'));
      await tester.pump();

      expect(checkoutCalled, true);
    });

    testWidgets('should call onItemRemove when remove button is tapped', (tester) async {
      String? removedProductId;

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cartWithItems,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) => removedProductId = productId,
            onClear: () {},
            onCheckout: () {},
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Tap the first close button
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();

      expect(removedProductId, isNotNull);
    });

    testWidgets('should display discount info when discount is applied', (tester) async {
      final product = createProduct(id: 'p1', name: 'Test Product', price: 10000);
      final discount = createProductDiscount(
        rateOrAmount: 10,
        method: 'PERCENTAGE',
      );

      final cartWithDiscount = Cart(items: [
        CartItem(
          product: product,
          quantity: 1,
          appliedDiscounts: [discount],
        ),
      ]);

      await tester.pumpWidget(createTestWidget(cartWithDiscount));
      await tester.pumpAndSettle();

      // Should show discount badge
      expect(findTextContaining('할인'), findsWidgets);
    });
  });

  group('CartItem Card', () {
    testWidgets('should display product quantity', (tester) async {
      final product = createProduct(id: 'p1', name: 'Test', price: 5000);
      final cart = Cart(items: [
        CartItem(product: product, quantity: 3),
      ]);

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cart,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) {},
            onClear: () {},
            onCheckout: () {},
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(findTextContaining('3'), findsOneWidget);
    });

    testWidgets('should show subtotal for each item', (tester) async {
      final product = createProduct(id: 'p1', name: 'Test', price: 5000);
      final cart = Cart(items: [
        CartItem(product: product, quantity: 2),
      ]);

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ko'),
        supportedLocales: const [
          Locale('ko'),
          Locale('en'),
          Locale('ja'),
          Locale('zh', 'TW'),
          Locale('zh', 'HK'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: CartSidebar(
            cart: cart,
            onQuantityChanged: (productId, quantity) {},
            onItemRemove: (productId) {},
            onClear: () {},
            onCheckout: () {},
            onTakeoutOrder: () {},
        isTableOrder: false,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Should display item subtotal (소계)
      expect(findTextContaining('소계'), findsOneWidget);
    });
  });
}

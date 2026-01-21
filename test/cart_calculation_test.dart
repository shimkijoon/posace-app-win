import 'package:flutter_test/flutter_test.dart';
import 'package:posace_app_win/core/models/cart.dart';
import 'package:posace_app_win/core/models/cart_item.dart';
import 'package:posace_app_win/data/local/models.dart';
import 'package:posace_app_win/data/local/models/taxes_models.dart';
import 'package:posace_app_win/data/local/models/options_models.dart';

void main() {
  group('Cart Calculation Tests', () {
    final storeId = 'store-1';
    final now = DateTime.now();

    final vatTax = TaxModel(
      id: 'tax-vat',
      storeId: storeId,
      name: 'VAT 10%',
      rate: 10.0,
      isInclusive: true,
      createdAt: now,
      updatedAt: now,
    );

    final salesTax = TaxModel(
      id: 'tax-sales',
      storeId: storeId,
      name: 'Sales Tax 5%',
      rate: 5.0,
      isInclusive: false,
      createdAt: now,
      updatedAt: now,
    );

    final product1 = ProductModel(
      id: 'p1',
      storeId: storeId,
      categoryId: 'c1',
      name: 'Product 1 (Inclusive Tax)',
      price: 11000,
      stockEnabled: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      taxes: [vatTax],
    );

    final product2 = ProductModel(
      id: 'p2',
      storeId: storeId,
      categoryId: 'c1',
      name: 'Product 2 (Exclusive Tax)',
      price: 10000,
      stockEnabled: false,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      taxes: [salesTax],
    );

    test('Inclusive Tax Calculation', () {
      final cart = Cart().addItem(product1, quantity: 1);
      
      expect(cart.subtotal, 11000);
      expect(cart.totalInclusiveTax, 1000); // 11000 - (11000 / 1.1)
      expect(cart.totalTax, 0); // Exclusive is 0
      expect(cart.total, 11000);
    });

    test('Exclusive Tax Calculation', () {
      final cart = Cart().addItem(product2, quantity: 1);
      
      expect(cart.subtotal, 10000);
      expect(cart.totalInclusiveTax, 0);
      expect(cart.totalTax, 500); // 10000 * 0.05
      expect(cart.total, 10500);
    });

    test('Option Price Adjustment', () {
      final option = ProductOptionModel(
        id: 'opt1',
        groupId: 'g1',
        name: 'Extra Large',
        priceAdjustment: 2000.0,
        sortOrder: 1,
      );

      final cart = Cart().addItem(product2, quantity: 1, selectedOptions: [option]);
      
      expect(cart.subtotal, 12000); // 10000 + 2000
      expect(cart.totalTax, 600); // 12000 * 0.05
      expect(cart.total, 12600);
    });

    test('Complex Calculation: Discount + Tax + Options', () {
      final option = ProductOptionModel(
        id: 'opt1',
        groupId: 'g1',
        name: 'Add Shot',
        priceAdjustment: 500.0,
        sortOrder: 1,
      );

      final discount = DiscountModel(
        id: 'd1',
        storeId: storeId,
        type: 'PRODUCT',
        targetId: 'p2',
        name: 'Promo',
        rateOrAmount: 1000,
        status: 'ACTIVE',
        createdAt: now,
        updatedAt: now,
      );

      var cart = Cart().addItem(product2, quantity: 2, selectedOptions: [option]);
      cart = cart.applyDiscounts([discount]);

      // Subtotal: (10000 + 500) * 2 = 21000
      // Discount: 1000 * 2 = 2000
      // Net Amount: 21000 - 2000 = 19000
      // Exclusive Tax: 19000 * 0.05 = 950
      // Total: 19000 + 950 = 19950

      expect(cart.subtotal, 21000);
      expect(cart.totalDiscountAmount, 2000);
      expect(cart.totalTax, 950);
      expect(cart.total, 19950);
    });
  });
}

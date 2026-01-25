import 'package:flutter_test/flutter_test.dart';
import 'package:posace_app_win/core/models/cart_item.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('CartItem', () {
    group('Base Price', () {
      test('should return product price as unit price', () {
        final product = createProduct(price: 10000);
        final item = CartItem(product: product, quantity: 1);

        expect(item.unitPrice, 10000);
      });

      test('should include option price adjustments', () {
        final product = createProduct(price: 10000);
        final option1 = createOption(priceAdjustment: 500);
        final option2 = createOption(id: 'opt-2', priceAdjustment: 300);

        final item = CartItem(
          product: product,
          quantity: 1,
          selectedOptions: [option1, option2],
        );

        // 10000 + 500 + 300 = 10800
        expect(item.unitPrice, 10800);
      });

      test('should use custom price when set', () {
        final product = createProduct(price: 10000);
        final item = CartItem(
          product: product,
          quantity: 1,
          customPrice: 8000,
        );

        expect(item.unitPrice, 8000);
      });
    });

    group('Total Price', () {
      test('should calculate total price with quantity', () {
        final product = createProduct(price: 5000);
        final item = CartItem(product: product, quantity: 3);

        expect(item.totalPrice, 15000);
      });

      test('should include options in total price', () {
        final product = createProduct(price: 5000);
        final option = createOption(priceAdjustment: 1000);
        final item = CartItem(
          product: product,
          quantity: 2,
          selectedOptions: [option],
        );

        // (5000 + 1000) * 2 = 12000
        expect(item.totalPrice, 12000);
      });
    });

    group('Discount Calculation', () {
      test('should calculate percentage discount', () {
        final product = createProduct(price: 10000);
        final discount = createProductDiscount(
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );

        final item = CartItem(
          product: product,
          quantity: 2,
          appliedDiscounts: [discount],
        );

        // 10000 * 10% * 2 = 2000
        expect(item.discountAmount, 2000);
      });

      test('should calculate fixed amount discount', () {
        final product = createProduct(price: 10000);
        final discount = createProductDiscount(
          rateOrAmount: 1000,
          method: 'AMOUNT',
        );

        final item = CartItem(
          product: product,
          quantity: 3,
          appliedDiscounts: [discount],
        );

        // 1000 * 3 = 3000
        expect(item.discountAmount, 3000);
      });

      test('should combine multiple discounts', () {
        final product = createProduct(price: 10000);
        final discount1 = createProductDiscount(
          id: 'd1',
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );
        final discount2 = createCategoryDiscount(
          id: 'd2',
          rateOrAmount: 500,
          method: 'AMOUNT',
        );

        final item = CartItem(
          product: product,
          quantity: 1,
          appliedDiscounts: [discount1, discount2],
        );

        // 10000 * 10% + 500 = 1500
        expect(item.discountAmount, 1500);
      });

      test('should return zero when no discounts applied', () {
        final product = createProduct(price: 10000);
        final item = CartItem(product: product, quantity: 1);

        expect(item.discountAmount, 0);
      });
    });

    group('Final Price', () {
      test('should subtract discount from total price', () {
        final product = createProduct(price: 10000);
        final discount = createProductDiscount(
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );

        final item = CartItem(
          product: product,
          quantity: 1,
          appliedDiscounts: [discount],
        );

        // 10000 - 1000 = 9000
        expect(item.finalPrice, 9000);
      });

      test('should not go below zero', () {
        final product = createProduct(price: 1000);
        final discount = createProductDiscount(
          rateOrAmount: 2000, // More than price
          method: 'AMOUNT',
        );

        final item = CartItem(
          product: product,
          quantity: 1,
          appliedDiscounts: [discount],
        );

        expect(item.finalPrice, 0);
      });
    });

    group('Tax Calculation', () {
      test('should calculate inclusive tax amount', () {
        final tax = createInclusiveTax(rate: 10.0);
        final product = createProduct(price: 11000, taxes: [tax]);
        final item = CartItem(product: product, quantity: 1);

        // 11000 - (11000 / 1.1) = 1000
        expect(item.inclusiveTaxAmount.round(), 1000);
      });

      test('should calculate exclusive tax amount', () {
        final tax = createExclusiveTax(rate: 5.0);
        final product = createProduct(price: 10000, taxes: [tax]);
        final item = CartItem(product: product, quantity: 1);

        // 10000 * 5% = 500
        expect(item.exclusiveTaxAmount.round(), 500);
      });

      test('should calculate tax on discounted price', () {
        final tax = createExclusiveTax(rate: 10.0);
        final product = createProduct(price: 10000, taxes: [tax]);
        final discount = createProductDiscount(
          rateOrAmount: 20,
          method: 'PERCENTAGE',
        );

        final item = CartItem(
          product: product,
          quantity: 1,
          appliedDiscounts: [discount],
        );

        // Final Price: 10000 - 2000 = 8000
        // Tax: 8000 * 10% = 800
        expect(item.finalPrice, 8000);
        expect(item.exclusiveTaxAmount.round(), 800);
      });

      test('should handle multiple taxes', () {
        final tax1 = createInclusiveTax(id: 't1', rate: 10.0);
        final tax2 = createExclusiveTax(id: 't2', rate: 5.0);
        final product = createProduct(price: 11000, taxes: [tax1, tax2]);
        final item = CartItem(product: product, quantity: 1);

        // Inclusive: 11000 - (11000 / 1.1) = 1000
        // Exclusive: 11000 * 5% = 550
        expect(item.inclusiveTaxAmount.round(), 1000);
        expect(item.exclusiveTaxAmount.round(), 550);
      });
    });

    group('Copy With', () {
      test('should create new instance with updated quantity', () {
        final product = createProduct(price: 10000);
        final item = CartItem(product: product, quantity: 1);
        final updatedItem = item.copyWith(quantity: 5);

        expect(updatedItem.quantity, 5);
        expect(item.quantity, 1); // Original unchanged
      });

      test('should preserve other fields when copying', () {
        final product = createProduct(price: 10000);
        final option = createOption();
        final discount = createProductDiscount();

        final item = CartItem(
          product: product,
          quantity: 2,
          selectedOptions: [option],
          appliedDiscounts: [discount],
        );

        final updatedItem = item.copyWith(quantity: 3);

        expect(updatedItem.selectedOptions.length, 1);
        expect(updatedItem.appliedDiscounts.length, 1);
      });
    });
  });
}

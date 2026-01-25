import 'package:flutter_test/flutter_test.dart';
import 'package:posace_app_win/core/models/cart.dart';
import 'package:posace_app_win/core/models/cart_item.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('Cart', () {
    group('Empty Cart', () {
      test('should be empty when created', () {
        final cart = Cart.empty();

        expect(cart.isEmpty, true);
        expect(cart.itemCount, 0);
        expect(cart.subtotal, 0);
        expect(cart.total, 0);
      });
    });

    group('Add Items', () {
      test('should add item to cart', () {
        final product = createProduct(price: 10000);
        final cart = Cart.empty().addItem(product);

        expect(cart.isEmpty, false);
        expect(cart.itemCount, 1);
        expect(cart.items.length, 1);
        expect(cart.items.first.product.id, product.id);
      });

      test('should increment quantity for same product', () {
        final product = createProduct(price: 10000);
        final cart = Cart.empty()
            .addItem(product, quantity: 1)
            .addItem(product, quantity: 2);

        expect(cart.items.length, 1);
        expect(cart.itemCount, 3);
        expect(cart.items.first.quantity, 3);
      });

      test('should add separate items for different options', () {
        final product = createProduct(price: 10000);
        final option1 = createOption(id: 'opt-1', name: 'Large');
        final option2 = createOption(id: 'opt-2', name: 'Small');

        final cart = Cart.empty()
            .addItem(product, selectedOptions: [option1])
            .addItem(product, selectedOptions: [option2]);

        expect(cart.items.length, 2);
        expect(cart.itemCount, 2);
      });
    });

    group('Remove Items', () {
      test('should remove item from cart', () {
        final product = createProduct(id: 'p1', price: 10000);
        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .removeItem('p1');

        expect(cart.isEmpty, true);
      });

      test('should clear all items', () {
        final product1 = createProduct(id: 'p1', price: 10000);
        final product2 = createProduct(id: 'p2', price: 5000);

        final cart = Cart.empty()
            .addItem(product1)
            .addItem(product2)
            .clear();

        expect(cart.isEmpty, true);
        expect(cart.items.length, 0);
      });
    });

    group('Update Quantity', () {
      test('should update item quantity', () {
        final product = createProduct(id: 'p1', price: 10000);
        final cart = Cart.empty()
            .addItem(product, quantity: 1)
            .updateItemQuantity('p1', 5);

        expect(cart.items.first.quantity, 5);
      });

      test('should remove item when quantity is zero', () {
        final product = createProduct(id: 'p1', price: 10000);
        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .updateItemQuantity('p1', 0);

        expect(cart.isEmpty, true);
      });
    });

    group('Subtotal Calculation', () {
      test('should calculate subtotal correctly', () {
        final product1 = createProduct(id: 'p1', price: 10000);
        final product2 = createProduct(id: 'p2', price: 5000);

        final cart = Cart.empty()
            .addItem(product1, quantity: 2)
            .addItem(product2, quantity: 3);

        // 10000 * 2 + 5000 * 3 = 35000
        expect(cart.subtotal, 35000);
      });

      test('should include option prices in subtotal', () {
        final product = createProduct(price: 10000);
        final option = createOption(priceAdjustment: 2000);

        final cart = Cart.empty()
            .addItem(product, quantity: 2, selectedOptions: [option]);

        // (10000 + 2000) * 2 = 24000
        expect(cart.subtotal, 24000);
      });
    });

    group('Discount Calculation', () {
      test('should apply product percentage discount', () {
        final product = createProduct(id: 'p1', price: 10000);
        final discount = createProductDiscount(
          productIds: ['p1'],
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([discount], []);

        // Subtotal: 20000, Discount: 20000 * 10% = 2000
        expect(cart.subtotal, 20000);
        expect(cart.productDiscountTotal, 2000);
      });

      test('should apply product fixed amount discount', () {
        final product = createProduct(id: 'p1', price: 10000);
        final discount = createProductDiscount(
          productIds: ['p1'],
          rateOrAmount: 1000,
          method: 'AMOUNT',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([discount], []);

        // Discount: 1000 * 2 = 2000
        expect(cart.productDiscountTotal, 2000);
      });

      test('should apply cart percentage discount', () {
        final product = createProduct(id: 'p1', price: 10000);
        final cartDiscount = createCartDiscount(
          rateOrAmount: 5,
          method: 'PERCENTAGE',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([cartDiscount], []);

        // Subtotal: 20000, Cart Discount: 20000 * 5% = 1000
        expect(cart.subtotal, 20000);
        expect(cart.cartDiscountTotal, 1000);
      });

      test('should apply cart fixed amount discount', () {
        final product = createProduct(id: 'p1', price: 10000);
        final cartDiscount = createCartDiscount(
          rateOrAmount: 3000,
          method: 'AMOUNT',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([cartDiscount], []);

        expect(cart.cartDiscountTotal, 3000);
      });

      test('should calculate total discount amount', () {
        final product = createProduct(id: 'p1', price: 10000);
        final productDiscount = createProductDiscount(
          productIds: ['p1'],
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );
        final cartDiscount = createCartDiscount(
          rateOrAmount: 5,
          method: 'PERCENTAGE',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([productDiscount, cartDiscount], []);

        // Product Discount: 20000 * 10% = 2000
        // Cart Discount: 20000 * 5% = 1000
        // Total Discount: 3000
        expect(cart.totalDiscountAmount, 3000);
      });
    });

    group('Tax Calculation', () {
      test('should not add inclusive tax to total', () {
        final tax = createInclusiveTax(rate: 10.0);
        final product = createProduct(price: 11000, taxes: [tax]);

        final cart = Cart.empty().addItem(product, quantity: 1);

        expect(cart.subtotal, 11000);
        expect(cart.totalTax, 0); // Exclusive tax is 0
        expect(cart.total, 11000); // Price already includes VAT
      });

      test('should add exclusive tax to total', () {
        final tax = createExclusiveTax(rate: 5.0);
        final product = createProduct(price: 10000, taxes: [tax]);

        final cart = Cart.empty().addItem(product, quantity: 1);

        expect(cart.subtotal, 10000);
        expect(cart.totalTax, 500); // 10000 * 5%
        expect(cart.total, 10500);
      });

      test('should handle mixed taxes', () {
        final inclusiveTax = createInclusiveTax(rate: 10.0);
        final exclusiveTax = createExclusiveTax(rate: 5.0);

        final product1 = createProduct(id: 'p1', price: 11000, taxes: [inclusiveTax]);
        final product2 = createProduct(id: 'p2', price: 10000, taxes: [exclusiveTax]);

        final cart = Cart.empty()
            .addItem(product1, quantity: 1)
            .addItem(product2, quantity: 1);

        // Subtotal: 11000 + 10000 = 21000
        // Exclusive Tax: 10000 * 5% = 500
        // Total: 21000 + 500 = 21500
        expect(cart.subtotal, 21000);
        expect(cart.totalTax, 500);
        expect(cart.total, 21500);
      });
    });

    group('Final Total Calculation', () {
      test('should calculate final total with discounts and taxes', () {
        final exclusiveTax = createExclusiveTax(rate: 5.0);
        final product = createProduct(price: 10000, taxes: [exclusiveTax]);
        final discount = createProductDiscount(
          productIds: [product.id],
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 2)
            .applyDiscounts([discount], []);

        // Subtotal: 20000
        // Product Discount: 20000 * 10% = 2000
        // Net Amount: 18000
        // Exclusive Tax: 18000 * 5% = 900
        // Final Total: 18000 + 900 = 18900
        expect(cart.subtotal, 20000);
        expect(cart.totalDiscountAmount, 2000);
        expect(cart.totalTax, 900);
        expect(cart.total, 18900);
      });

      test('should not go below zero', () {
        final product = createProduct(id: 'p1', price: 1000);
        final discount = createCartDiscount(
          rateOrAmount: 5000, // More than total
          method: 'AMOUNT',
        );

        final cart = Cart.empty()
            .addItem(product, quantity: 1)
            .applyDiscounts([discount], []);

        expect(cart.total >= 0, true);
      });
    });
  });
}

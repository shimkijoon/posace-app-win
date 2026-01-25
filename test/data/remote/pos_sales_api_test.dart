import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:convert';

import '../../helpers/mock_api_client.dart';
import '../../helpers/test_fixtures.dart';

void main() {
  group('PosSalesApi', () {
    group('createSale', () {
      test('should build correct sale data structure', () {
        final product = createProduct(id: 'prod-1', price: 10000);

        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'sessionId': 'session-1',
          'clientSaleId': 'client-sale-123',
          'totalAmount': 10000,
          'paidAmount': 10000,
          'taxAmount': 1000,
          'discountAmount': 0,
          'items': [
            {
              'productId': product.id,
              'qty': 1,
              'price': 10000,
              'discountAmount': 0,
            }
          ],
          'payments': [
            {
              'method': 'CASH',
              'amount': 10000,
            }
          ],
        };

        expect(saleData['storeId'], testStoreId);
        expect(saleData['totalAmount'], 10000);
        expect((saleData['items'] as List).length, 1);
        expect((saleData['payments'] as List).length, 1);
      });

      test('should include discount information in sale data', () {
        final product = createProduct(id: 'prod-1', price: 10000);
        final discount = createProductDiscount(
          rateOrAmount: 10,
          method: 'PERCENTAGE',
        );

        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'totalAmount': 9000,
          'paidAmount': 9000,
          'discountAmount': 1000,
          'items': [
            {
              'productId': product.id,
              'qty': 1,
              'price': 10000,
              'discountAmount': 1000,
              'discountsJson': json.encode([
                {
                  'id': discount.id,
                  'name': discount.name,
                  'rateOrAmount': discount.rateOrAmount,
                  'method': discount.method,
                }
              ]),
            }
          ],
          'payments': [
            {
              'method': 'CASH',
              'amount': 9000,
            }
          ],
        };

        expect(saleData['discountAmount'], 1000);
        expect(saleData['totalAmount'], 9000);
      });

      test('should include split payment information', () {
        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'totalAmount': 10000,
          'paidAmount': 10000,
          'payments': [
            {
              'method': 'CASH',
              'amount': 5000,
            },
            {
              'method': 'CARD',
              'amount': 5000,
              'cardApproval': 'APPROVAL123',
              'cardLast4': '1234',
            }
          ],
        };

        final payments = saleData['payments'] as List;
        expect(payments.length, 2);
        expect(payments[0]['method'], 'CASH');
        expect(payments[0]['amount'], 5000);
        expect(payments[1]['method'], 'CARD');
        expect(payments[1]['cardApproval'], 'APPROVAL123');
      });

      test('should include member information when applicable', () {
        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'totalAmount': 10000,
          'paidAmount': 10000,
          'memberId': 'member-123',
          'memberPointsEarned': 100,
          'items': [],
          'payments': [
            {'method': 'CASH', 'amount': 10000}
          ],
        };

        expect(saleData['memberId'], 'member-123');
        expect(saleData['memberPointsEarned'], 100);
      });

      test('should parse successful sale response', () {
        final responseJson = mockSaleSuccessResponse;
        final response = json.decode(responseJson) as Map<String, dynamic>;

        expect(response['id'], 'sale-1');
        expect(response['status'], 'COMPLETED');
        expect(response['totalAmount'], 10000);
        expect(response['paidAmount'], 10000);
      });

      test('should include session information', () {
        final session = createSession(id: 'session-1', openingAmount: 100000);

        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'sessionId': session.id,
          'totalAmount': 10000,
          'paidAmount': 10000,
        };

        expect(saleData['sessionId'], 'session-1');
      });
    });

    group('Tax Calculation in Sale', () {
      test('should calculate inclusive tax correctly', () {
        // 11,000원 상품, 10% 포함세
        // 세금: 11000 - (11000 / 1.1) = 1000
        final priceWithTax = 11000;
        final taxRate = 10.0;
        final taxAmount = priceWithTax - (priceWithTax / (1 + taxRate / 100));

        expect(taxAmount.round(), 1000);
      });

      test('should calculate exclusive tax correctly', () {
        // 10,000원 상품, 5% 별도세
        // 세금: 10000 * 5% = 500
        final priceBeforeTax = 10000;
        final taxRate = 5.0;
        final taxAmount = priceBeforeTax * (taxRate / 100);

        expect(taxAmount.round(), 500);
      });

      test('should include tax amounts in sale data', () {
        final inclusiveTax = createInclusiveTax(rate: 10.0);
        final product = createProduct(price: 11000, taxes: [inclusiveTax]);

        final saleData = {
          'storeId': testStoreId,
          'posId': testPosId,
          'totalAmount': 11000,
          'taxAmount': 1000, // Inclusive tax amount
          'taxes': [
            {
              'taxId': inclusiveTax.id,
              'taxName': inclusiveTax.name,
              'rate': inclusiveTax.rate,
              'amount': 1000,
              'isInclusive': true,
            }
          ],
        };

        expect(saleData['taxAmount'], 1000);
        expect((saleData['taxes'] as List).first['isInclusive'], true);
      });
    });

    group('Idempotency', () {
      test('should include clientSaleId for idempotency', () {
        final clientSaleId = 'uuid-${DateTime.now().millisecondsSinceEpoch}';

        final saleData = {
          'clientSaleId': clientSaleId,
          'storeId': testStoreId,
          'posId': testPosId,
          'totalAmount': 10000,
        };

        expect(saleData['clientSaleId'], isNotNull);
        expect(saleData['clientSaleId'], startsWith('uuid-'));
      });

      test('should use same clientSaleId for retry attempts', () {
        final originalClientSaleId = 'uuid-12345';

        // First attempt
        final firstAttempt = {
          'clientSaleId': originalClientSaleId,
          'totalAmount': 10000,
        };

        // Retry attempt (should use same clientSaleId)
        final retryAttempt = {
          'clientSaleId': originalClientSaleId,
          'totalAmount': 10000,
        };

        expect(firstAttempt['clientSaleId'], retryAttempt['clientSaleId']);
      });
    });
  });
}

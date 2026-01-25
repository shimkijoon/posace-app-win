import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

class MockHttpClient extends Mock implements http.Client {}

class MockResponse extends Mock implements http.Response {
  final String _body;
  final int _statusCode;

  MockResponse({String body = '{}', int statusCode = 200})
      : _body = body,
        _statusCode = statusCode;

  @override
  String get body => _body;

  @override
  int get statusCode => _statusCode;
}

// Mock API responses
const mockLoginResponse = '''
{
  "accessToken": "mock-access-token",
  "storeId": "store-1",
  "posId": "pos-1",
  "storeName": "Test Store",
  "businessNumber": "123-45-67890"
}
''';

const mockMasterDataResponse = '''
{
  "store": {
    "id": "store-1",
    "name": "Test Store",
    "currency": "KRW",
    "country": "KR",
    "timezone": "Asia/Seoul"
  },
  "categories": [
    {"id": "cat-1", "storeId": "store-1", "name": "Drinks", "sortOrder": 0, "allowProductDiscount": true, "createdAt": "2024-01-01T00:00:00Z", "updatedAt": "2024-01-01T00:00:00Z"}
  ],
  "products": [
    {"id": "prod-1", "storeId": "store-1", "categoryId": "cat-1", "name": "Americano", "type": "SINGLE", "price": 5500, "stockEnabled": false, "isActive": true, "createdAt": "2024-01-01T00:00:00Z", "updatedAt": "2024-01-01T00:00:00Z", "taxes": []}
  ],
  "discounts": [],
  "taxes": [
    {"id": "tax-1", "storeId": "store-1", "name": "VAT 10%", "rate": 10.0, "isInclusive": true, "createdAt": "2024-01-01T00:00:00Z", "updatedAt": "2024-01-01T00:00:00Z"}
  ]
}
''';

const mockSaleSuccessResponse = '''
{
  "id": "sale-1",
  "storeId": "store-1",
  "posId": "pos-1",
  "totalAmount": 10000,
  "paidAmount": 10000,
  "status": "COMPLETED",
  "items": [],
  "payments": [],
  "taxes": []
}
''';

const mockSessionOpenResponse = '''
{
  "id": "session-1",
  "storeId": "store-1",
  "posId": "pos-1",
  "openingAmount": 100000,
  "status": "OPEN",
  "openedAt": "2024-01-01T09:00:00Z"
}
''';

const mockSessionCloseResponse = '''
{
  "id": "session-1",
  "storeId": "store-1",
  "posId": "pos-1",
  "openingAmount": 100000,
  "closingAmount": 150000,
  "expectedAmount": 145000,
  "variance": 5000,
  "status": "CLOSED",
  "openedAt": "2024-01-01T09:00:00Z",
  "closedAt": "2024-01-01T21:00:00Z",
  "totalSales": 50000,
  "totalRefunds": 5000,
  "totalCash": 45000,
  "salesCount": 10,
  "refundCount": 1
}
''';

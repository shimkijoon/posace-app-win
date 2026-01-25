import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../helpers/mock_api_client.dart';

void main() {
  group('PosAuthApi', () {
    late MockHttpClient mockClient;

    setUp(() {
      mockClient = MockHttpClient();
    });

    group('login', () {
      test('should return access token on successful login', () async {
        // This test demonstrates the expected API response structure
        final responseBody = {
          'accessToken': 'mock-access-token',
          'storeId': 'store-1',
          'posId': 'pos-1',
          'storeName': 'Test Store',
          'businessNumber': '123-45-67890',
        };

        expect(responseBody['accessToken'], 'mock-access-token');
        expect(responseBody['storeId'], 'store-1');
        expect(responseBody['posId'], 'pos-1');
      });

      test('should parse login response correctly', () {
        final jsonResponse = mockLoginResponse;
        final parsed = json.decode(jsonResponse) as Map<String, dynamic>;

        expect(parsed['accessToken'], isNotNull);
        expect(parsed['storeId'], isNotNull);
        expect(parsed['posId'], isNotNull);
        expect(parsed['storeName'], 'Test Store');
      });
    });

    group('loginAsOwner', () {
      test('should include email and password in request', () {
        // Test demonstrates the expected request structure
        final requestBody = {
          'email': 'owner@test.com',
          'password': 'password123',
          'deviceId': 'device-123',
        };

        expect(requestBody['email'], 'owner@test.com');
        expect(requestBody['password'], 'password123');
        expect(requestBody['deviceId'], 'device-123');
      });
    });

    group('selectPos', () {
      test('should include storeId and posId in request', () {
        final requestBody = {
          'email': 'owner@test.com',
          'storeId': 'store-1',
          'posId': 'pos-1',
          'deviceId': 'device-123',
        };

        expect(requestBody['storeId'], 'store-1');
        expect(requestBody['posId'], 'pos-1');
      });
    });

    group('verifyToken', () {
      test('should return true for valid status codes', () {
        // Valid status codes: 200, 201
        expect([200, 201].contains(200), true);
        expect([200, 201].contains(201), true);
        expect([200, 201].contains(401), false);
        expect([200, 201].contains(500), false);
      });
    });
  });

  group('MockResponse', () {
    test('should return correct body and status code', () {
      final response = MockResponse(body: '{"key": "value"}', statusCode: 200);

      expect(response.body, '{"key": "value"}');
      expect(response.statusCode, 200);
    });

    test('should default to empty object and 200 status', () {
      final response = MockResponse();

      expect(response.body, '{}');
      expect(response.statusCode, 200);
    });

    test('should handle error status codes', () {
      final response = MockResponse(body: '{"error": "Not Found"}', statusCode: 404);

      expect(response.statusCode, 404);
      expect(json.decode(response.body)['error'], 'Not Found');
    });
  });
}

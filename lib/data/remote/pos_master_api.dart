import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../local/models.dart';

class PosMasterApi {
  PosMasterApi(this.apiClient);

  final ApiClient apiClient;

  Future<MasterDataResponse> getMasterData(String storeId, {String? updatedAfter}) async {
    final uri = apiClient.buildUri(
      '/pos/stores/$storeId/master',
      updatedAfter != null ? {'updatedAfter': updatedAfter} : null,
    );

    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch master data: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return MasterDataResponse.fromJson(data);
  }
}

class MasterDataResponse {
  final String serverTime;
  final StoreInfo store;
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<DiscountModel> discounts;

  MasterDataResponse({
    required this.serverTime,
    required this.store,
    required this.categories,
    required this.products,
    required this.discounts,
  });

  factory MasterDataResponse.fromJson(Map<String, dynamic> json) {
    return MasterDataResponse(
      serverTime: json['serverTime'] as String,
      store: StoreInfo.fromJson(json['store'] as Map<String, dynamic>),
      categories: (json['categories'] as List)
          .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      products: (json['products'] as List)
          .map((e) => ProductModel.fromMap(e as Map<String, dynamic>))
          .toList(),
      discounts: (json['discounts'] as List)
          .map((e) => DiscountModel.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StoreInfo {
  final String id;
  final String name;
  final String timezone;
  final String currency;
  final List<PosDeviceInfo> posDevices;

  StoreInfo({
    required this.id,
    required this.name,
    required this.timezone,
    required this.currency,
    required this.posDevices,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String,
      currency: json['currency'] as String,
      posDevices: (json['posDevices'] as List)
          .map((e) => PosDeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class PosDeviceInfo {
  final String id;
  final String name;
  final String status;

  PosDeviceInfo({
    required this.id,
    required this.name,
    required this.status,
  });

  factory PosDeviceInfo.fromJson(Map<String, dynamic> json) {
    return PosDeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      status: json['status'] as String,
    );
  }
}

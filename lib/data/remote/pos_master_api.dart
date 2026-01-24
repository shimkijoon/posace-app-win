import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../local/models.dart';
import '../local/models/taxes_models.dart';

class PosMasterApi {
  PosMasterApi(this.apiClient);

  final ApiClient apiClient;

  Future<MasterDataResponse> getMasterData(String storeId, {String? updatedAfter}) async {
    final uri = apiClient.buildUri(
      '/pos/stores/$storeId/master',
      updatedAfter != null ? {'updatedAfter': updatedAfter} : null,
    );

    print('[POS] Requesting Master Data from: $uri');
    final response = await http.get(
      uri,
      headers: {
        'Content-Type': 'application/json',
        if (apiClient.accessToken != null) 'Authorization': 'Bearer ${apiClient.accessToken}',
      },
    );

    print('[POS] Master Data Response Status: ${response.statusCode}');

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch master data: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final layouts = data['tableLayouts'] as List?;
    print('[POS] Received ${layouts?.length ?? 0} layouts from API');
    final products = data['products'] as List?;
    print('[POS] Received ${products?.length ?? 0} products from API');
    return MasterDataResponse.fromJson(data);
  }
}

class MasterDataResponse {
  final String serverTime;
  final StoreInfo store;
  final List<CategoryModel> categories;
  final List<ProductModel> products;
  final List<DiscountModel> discounts;
  final List<TaxModel> taxes;
  final List<TableLayoutData> tableLayouts;

  MasterDataResponse({
    required this.serverTime,
    required this.store,
    required this.categories,
    required this.products,
    required this.discounts,
    required this.taxes,
    required this.tableLayouts,
  });

  factory MasterDataResponse.fromJson(Map<String, dynamic> json) {
    try {
      return MasterDataResponse(
        serverTime: json['serverTime'] as String,
        store: StoreInfo.fromJson(json['store'] as Map<String, dynamic>),
        categories: (json['categories'] as List)
            .map((e) => CategoryModel.fromMap(e as Map<String, dynamic>))
            .toList(),
        products: (json['products'] as List).map((e) {
          try {
            return ProductModel.fromMap(e as Map<String, dynamic>);
          } catch (e) {
            print('[POS] Error parsing product: $e');
            rethrow;
          }
        }).toList(),
        discounts: (json['discounts'] as List)
            .map((e) => DiscountModel.fromMap(e as Map<String, dynamic>))
            .toList(),
        taxes: (json['taxes'] as List? ?? [])
            .map((e) => TaxModel.fromMap(e as Map<String, dynamic>))
            .toList(),
        tableLayouts: (json['tableLayouts'] as List? ?? [])
            .map((e) => TableLayoutData.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (e, stack) {
      print('[POS] Error parsing MasterDataResponse: $e');
      print(stack);
      rethrow;
    }
  }
}

class TableLayoutData {
  final String id;
  final String storeId;
  final String name;
  final int sortOrder;
  final List<RestaurantTableData> tables;

  TableLayoutData({
    required this.id,
    required this.storeId,
    required this.name,
    required this.sortOrder,
    required this.tables,
  });

  factory TableLayoutData.fromJson(Map<String, dynamic> json) {
    return TableLayoutData(
      id: json['id'] as String,
      storeId: json['storeId'] as String,
      name: json['name'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      tables: (json['tables'] as List? ?? [])
          .map((e) => RestaurantTableData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'sortOrder': sortOrder,
      'tables': tables.map((t) => t.toMap()).toList(),
    };
  }
}

class RestaurantTableData {
  final String id;
  final String layoutId;
  final String tableNumber;
  final int? capacity;
  final String? shape;
  final double posX;
  final double posY;
  final double width;
  final double height;
  final bool isActive;

  RestaurantTableData({
    required this.id,
    required this.layoutId,
    required this.tableNumber,
    this.capacity,
    this.shape,
    required this.posX,
    required this.posY,
    required this.width,
    required this.height,
    required this.isActive,
  });

  factory RestaurantTableData.fromJson(Map<String, dynamic> json) {
    return RestaurantTableData(
      id: json['id'] as String,
      layoutId: json['layoutId'] as String,
      tableNumber: json['tableNumber'] as String,
      capacity: json['capacity'] as int?,
      shape: json['shape'] as String?,
      posX: (json['posX'] as num?)?.toDouble() ?? 0.0,
      posY: (json['posY'] as num?)?.toDouble() ?? 0.0,
      width: (json['width'] as num?)?.toDouble() ?? 80.0,
      height: (json['height'] as num?)?.toDouble() ?? 80.0,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'layoutId': layoutId,
      'name': tableNumber,
      'x': posX,
      'y': posY,
      'width': width,
      'height': height,
    };
  }
}

class StoreInfo {
  final String id;
  final String name;
  final String timezone;
  final String currency;
  final String? businessNumber;
  final String? address;
  final String? phone;
  final List<PosDeviceInfo> posDevices;

  StoreInfo({
    required this.id,
    required this.name,
    required this.timezone,
    required this.currency,
    this.businessNumber,
    this.address,
    this.phone,
    required this.posDevices,
  });

  factory StoreInfo.fromJson(Map<String, dynamic> json) {
    return StoreInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      timezone: json['timezone'] as String,
      currency: json['currency'] as String,
      businessNumber: json['businessNumber'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
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

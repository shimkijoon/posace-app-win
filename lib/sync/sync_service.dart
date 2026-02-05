import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/local/app_database.dart';
import '../data/local/models.dart';
import '../data/remote/pos_master_api.dart';
import '../data/remote/pos_sales_api.dart';
import '../core/storage/auth_storage.dart';

class SyncService {
  SyncService({
    required this.database,
    required this.masterApi,
    required this.salesApi,
  });

  final AppDatabase database;
  final PosMasterApi masterApi;
  final PosSalesApi salesApi;
  final AuthStorage authStorage = AuthStorage();

  Future<SyncResult> syncMaster({
    required String storeId,
    bool manual = false,
  }) async {
    final resultErrors = <String>[];
    int? categoriesCount;
    int? productsCount;
    int? discountsCount;
    int? taxesCount;
    int? tableLayoutsCount;
    int? kitchenStationsCount;
    int? membersCount;
    String? serverTime;

    try {
      print('[POS] Starting Master Sync...');
      
      // 마지막 동기화 시간 확인
      final lastSyncTime = await database.getSyncMetadata('lastMasterSync');
      final updatedAfter = manual ? null : lastSyncTime;

      // 서버에서 마스터 데이터 다운로드
      print('[POS] Fetching data from API...');
      final response = await masterApi.getMasterData(storeId, updatedAfter: updatedAfter);
      serverTime = response.serverTime;

      // 로컬 DB에 저장 - 각 단계별 에러 처리
      try {
        print('[POS] Saving ${response.categories.length} categories');
        await database.upsertCategories(response.categories);
        categoriesCount = response.categories.length;
      } catch (e) {
        print('[POS] Category sync failed: $e');
        resultErrors.add('Category sync failed: $e');
      }

      try {
        print('[POS] Saving ${response.products.length} products');
        await database.upsertProducts(response.products);
        productsCount = response.products.length;
      } catch (e) {
        print('[POS] Product sync failed: $e');
        resultErrors.add('Product sync failed: $e');
      }

      try {
        await database.upsertDiscounts(response.discounts);
        discountsCount = response.discounts.length;
      } catch (e) {
        print('[POS] Discount sync failed: $e');
        resultErrors.add('Discount sync failed: $e');
      }

      try {
        await database.upsertTaxes(response.taxes);
        taxesCount = response.taxes.length;
      } catch (e) {
        print('[POS] Tax sync failed: $e');
        resultErrors.add('Tax sync failed: $e');
      }

      // 테이블 레이아웃 저장
      try {
        print('[POS] Saving ${response.tableLayouts.length} layouts to local DB');
        await database.upsertTableLayouts(
          response.tableLayouts.map((layout) => layout.toMap()).toList(),
        );
        tableLayoutsCount = response.tableLayouts.length;
      } catch (e) {
        print('[POS] Table Layout sync failed: $e');
        resultErrors.add('Table Layout sync failed: $e');
      }

      // 주방 스테이션 저장
      try {
        print('[POS] Saving ${response.kitchenStations.length} kitchen stations');
        await database.upsertKitchenStations(response.kitchenStations);
        kitchenStationsCount = response.kitchenStations.length;
      } catch (e) {
        print('[POS] Kitchen Station sync failed: $e');
        resultErrors.add('Kitchen Station sync failed: $e');
      }

      // 동기화 시간 업데이트
      await database.setSyncMetadata('lastMasterSync', response.serverTime);

      // 매장 정보 업데이트
      try {
        final session = await authStorage.getSessionInfo();
        await authStorage.saveSession(
          accessToken: session['accessToken'] ?? '',
          storeId: session['storeId'] ?? '',
          posId: session['posId'] ?? '',
          storeName: response.store.name,
          storeBizNo: response.store.businessNumber,
          storeAddr: response.store.address,
          storePhone: response.store.phone,
        );
      } catch (e) {
        print('[POS] Store info update failed: $e');
        // This is not critical, so we don't add to resultErrors
      }

      // 회원 동기화 추가
      try {
        membersCount = await syncMembers(storeId: storeId);
      } catch (e) {
        print('[POS] Member sync failed: $e');
        resultErrors.add('Member sync failed: $e');
      }

      return SyncResult(
        success: resultErrors.isEmpty,
        categoriesCount: categoriesCount,
        productsCount: productsCount,
        discountsCount: discountsCount,
        taxesCount: taxesCount,
        tableLayoutsCount: tableLayoutsCount,
        kitchenStationsCount: kitchenStationsCount, // Added to SyncResult
        membersCount: membersCount,
        serverTime: serverTime,
        error: resultErrors.isNotEmpty ? resultErrors.join('\n') : null,
      );
    } catch (e, stack) {
      print('[POS] Critical Sync Error: $e');
      print(stack);
      return SyncResult(
        success: false,
        error: 'Critical error: $e',
      );
    }
  }

  Future<int> syncMembers({required String storeId}) async {
    try {
      // Changed to use POS-specific endpoint that doesn't check owner permissions
      final uri = masterApi.apiClient.buildUri('/pos/customers/list');
      final accessToken = await authStorage.getAccessToken();
      print('[POS] Syncing members from $uri');
      
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );

      print('[POS] Member sync status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('[POS] Found ${data.length} members');
        
        int successCount = 0;
        int skipCount = 0;

        for (final item in data) {
          try {
            final customer = item['customer'];
            if (customer == null) {
              skipCount++;
              continue;
            }

            final String? phoneNumber = customer['phoneNumber'];
            if (phoneNumber == null || phoneNumber.isEmpty) {
              // 전화번호가 없으면 로컬 DB 제약조건(NOT NULL) 때문에 저장 불가하므로 건너뜀
              print('[POS] Skipping member ${item['id']} due to missing phone number');
              skipCount++;
              continue; 
            }

            final member = MemberModel(
              id: item['id'] ?? '',
              storeId: storeId,
              name: customer['name'] ?? '고객',
              phone: phoneNumber,
              points: (item['pointsBalance'] as num?)?.toInt() ?? 0,
              createdAt: item['createdAt'] != null ? DateTime.parse(item['createdAt']) : DateTime.now(),
              updatedAt: item['updatedAt'] != null ? DateTime.parse(item['updatedAt']) : DateTime.now(),
            );
            await database.upsertMember(member);
            successCount++;
          } catch (e) {
            print('[POS] Failed to process member item: $e');
            skipCount++;
          }
        }
        print('[POS] Member sync completed. Success: $successCount, Skipped: $skipCount');
        return successCount;
      } else {
        throw Exception('Failed to fetch members: ${response.statusCode}');
      }
    } catch (e) {
      print('[POS] syncMembers error: $e');
      rethrow; // 상위에서 잡아서 결과에 포함시키기 위해 rethrow
    }
  }

  Future<int> flushSalesQueue() async {
    final unsyncedSales = await database.getUnsyncedSales();
    int successCount = 0;

    for (final sale in unsyncedSales) {
      try {
        final items = await database.getSaleItems(sale.id);
        
        final saleData = {
          'storeId': sale.storeId,
          'posId': sale.posId,
          'clientSaleId': sale.id, // 로컬 ID를 클라이언트 세일 ID로 사용
          'saleDate': sale.saleDate != null 
              ? sale.saleDate!.toIso8601String().split('T')[0] 
              : sale.createdAt.toIso8601String().split('T')[0], // YYYY-MM-DD
          'saleTime': sale.saleTime ?? 
              sale.createdAt.toIso8601String().split('T')[1].substring(0, 8), // HH:mm:ss
          'totalAmount': sale.totalAmount,
          'paidAmount': sale.paidAmount,
          // 'paymentMethod': sale.paymentMethod, // Removed
          'status': sale.status,
          'items': items.map((item) => {
            'productId': item.productId,
            'qty': item.qty,
            'price': item.price,
            'discountAmount': item.discountAmount,
          }).toList(),
          'payments': sale.payments.map((p) => {
            'method': p.method,
            'amount': p.amount,
            'cardApproval': p.cardApproval, 
            'cardLast4': p.cardLast4,
          }).toList(),
        };

        await salesApi.createSale(saleData);
        await database.markSaleAsSynced(sale.id);
        successCount++;
      } catch (e) {
        print('Failed to sync sale ${sale.id}: $e');
        // 한 건 실패해도 다음 건 계속 진행
      }
    }

    return successCount;
  }

  Future<void> clearLocalData() async {
    await database.clearAll();
  }
}

class SyncResult {
  final bool success;
  final int? categoriesCount;
  final int? productsCount;
  final int? discountsCount;
  final int? taxesCount;
  final int? tableLayoutsCount;
  final int? kitchenStationsCount;
  final int? membersCount;
  final String? serverTime;
  final String? error;

  SyncResult({
    required this.success,
    this.categoriesCount,
    this.productsCount,
    this.discountsCount,
    this.taxesCount,
    this.tableLayoutsCount,
    this.kitchenStationsCount,
    this.membersCount,
    this.serverTime,
    this.error,
  });
}

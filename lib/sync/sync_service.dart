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
    try {
      print('[POS] Starting Master Sync...');
      // 마지막 동기화 시간 확인
      final lastSyncTime = await database.getSyncMetadata('lastMasterSync');
      final updatedAfter = manual ? null : lastSyncTime;

      // 서버에서 마스터 데이터 다운로드
      final response = await masterApi.getMasterData(storeId, updatedAfter: updatedAfter);

      // 로컬 DB에 저장
      print('[POS] Saving ${response.categories.length} categories');
      await database.upsertCategories(response.categories);
      print('[POS] Saving ${response.products.length} products');
      await database.upsertProducts(response.products);
      await database.upsertDiscounts(response.discounts);
      await database.upsertTaxes(response.taxes);

      // 테이블 레이아웃 저장
      print('[POS] Saving ${response.tableLayouts.length} layouts to local DB');
      await database.upsertTableLayouts(
        response.tableLayouts.map((layout) => layout.toMap()).toList(),
      );

      // 주방 스테이션 저장
      print('[POS] Saving ${response.kitchenStations.length} kitchen stations');
      await database.upsertKitchenStations(response.kitchenStations);

      // 동기화 시간 업데이트
      await database.setSyncMetadata('lastMasterSync', response.serverTime);

      // 매장 정보 업데이트
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

      // 회원 동기화 추가
      int membersCount = 0;
      try {
        membersCount = await syncMembers(storeId: storeId);
      } catch (e) {
        print('[POS] Member sync failed: $e');
      }

      return SyncResult(
        success: true,
        categoriesCount: response.categories.length,
        productsCount: response.products.length,
        discountsCount: response.discounts.length,
        taxesCount: response.taxes.length,
        tableLayoutsCount: response.tableLayouts.length,
        membersCount: membersCount,
        serverTime: response.serverTime,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<int> syncMembers({required String storeId}) async {
    // API에 모든 멤버 조회 엔드포인트가 있다고 가정하고 구현
    // 만약 현재 API에 없다면, 나중에 추가하거나 현재는 빈 값 반환
    try {
      final uri = masterApi.apiClient.buildUri('/customers/store/$storeId');
      final accessToken = await authStorage.getAccessToken();
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          if (accessToken != null) 'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        for (final item in data) {
          final customer = item['customer'];
          final member = MemberModel(
            id: item['id'],
            storeId: storeId,
            name: customer['name'] ?? '고객',
            phone: customer['phoneNumber'],
            points: (item['pointsBalance'] as num?)?.toInt() ?? 0,
            createdAt: DateTime.parse(item['createdAt']),
            updatedAt: DateTime.parse(item['updatedAt']),
          );
          await database.upsertMember(member);
        }
        return data.length;
      }
    } catch (e) {
      print('[POS] syncMembers error: $e');
    }
    return 0;
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
          'saleDate': sale.createdAt.toIso8601String().split('T')[0], // YYYY-MM-DD
          'saleTime': sale.createdAt.toIso8601String().split('T')[1].substring(0, 8), // HH:mm:ss
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
    this.membersCount,
    this.serverTime,
    this.error,
  });
}

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
      // 마지막 동기화 시간 확인
      final lastSyncTime = await database.getSyncMetadata('lastMasterSync');
      final updatedAfter = manual ? null : lastSyncTime;

      // 서버에서 마스터 데이터 다운로드
      final response = await masterApi.getMasterData(storeId, updatedAfter: updatedAfter);

      // 로컬 DB에 저장
      await database.upsertCategories(response.categories);
      await database.upsertProducts(response.products);
      await database.upsertDiscounts(response.discounts);
      await database.upsertTaxes(response.taxes);

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

      return SyncResult(
        success: true,
        categoriesCount: response.categories.length,
        productsCount: response.products.length,
        discountsCount: response.discounts.length,
        taxesCount: response.taxes.length,
        serverTime: response.serverTime,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
      );
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
          'totalAmount': sale.totalAmount,
          'paidAmount': sale.paidAmount,
          'paymentMethod': sale.paymentMethod,
          'status': sale.status,
          'items': items.map((item) => {
            'productId': item.productId,
            'qty': item.qty,
            'price': item.price,
            'discountAmount': item.discountAmount,
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
  final String? serverTime;
  final String? error;

  SyncResult({
    required this.success,
    this.categoriesCount,
    this.productsCount,
    this.discountsCount,
    this.taxesCount,
    this.serverTime,
    this.error,
  });
}

import '../data/local/app_database.dart';
import '../data/remote/pos_master_api.dart';
import '../data/remote/api_client.dart';

class SyncService {
  SyncService({
    required this.database,
    required this.masterApi,
  });

  final AppDatabase database;
  final PosMasterApi masterApi;

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

      // 동기화 시간 업데이트
      await database.setSyncMetadata('lastMasterSync', response.serverTime);

      return SyncResult(
        success: true,
        categoriesCount: response.categories.length,
        productsCount: response.products.length,
        discountsCount: response.discounts.length,
        serverTime: response.serverTime,
      );
    } catch (e) {
      return SyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<void> flushSalesQueue() async {
    // TODO: Implement queued sales upload.
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
  final String? serverTime;
  final String? error;

  SyncResult({
    required this.success,
    this.categoriesCount,
    this.productsCount,
    this.discountsCount,
    this.serverTime,
    this.error,
  });
}

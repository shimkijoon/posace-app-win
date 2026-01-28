import '../../core/storage/auth_storage.dart';
import '../../data/remote/pos_auth_api.dart';

class PosAuthService {
  PosAuthService({PosAuthApi? api, AuthStorage? storage})
      : _api = api ?? PosAuthApi(),
        _storage = storage ?? AuthStorage();

  final PosAuthApi _api;
  final AuthStorage _storage;

  Future<void> loginWithDeviceToken(String deviceToken) async {
    final result = await _api.login(deviceToken);
    final accessToken = result['accessToken'] as String?;
    final storeId = result['storeId'] as String?;
    final posId = result['posId'] as String?;

    if (accessToken == null || storeId == null || posId == null) {
      throw Exception('응답 형식이 올바르지 않습니다.');
    }

    await _storage.saveSession(
      accessToken: accessToken,
      storeId: storeId,
      posId: posId,
      uiLanguage: result['uiLanguage'] as String?,
    );
  }

  Future<Map<String, dynamic>> loginAsOwner(String email, String password, {String? deviceId}) async {
    final result = await _api.loginAsOwner(email, password, deviceId: deviceId);
    
    print('[PosAuthService] loginAsOwner response: $result');
    
    final bool autoSelected = result['autoSelected'] ?? false;
    
    if (autoSelected) {
      final accessToken = result['accessToken'] as String?;
      final storeId = result['storeId'] as String?;
      final posId = result['posId'] as String?;
      final uiLanguage = result['uiLanguage'] as String?;

      print('[PosAuthService] autoSelected path - uiLanguage from response: $uiLanguage');

      if (accessToken == null || storeId == null || posId == null) {
        throw Exception('응답 형식이 올바르지 않습니다.');
      }

      await _storage.saveSession(
        accessToken: accessToken,
        storeId: storeId,
        posId: posId,
        storeName: result['storeName'],
        storeBizNo: result['businessNumber'],
        storeAddr: result['address'],
        storePhone: result['phone'],
        uiLanguage: uiLanguage,
      );
      
      print('[PosAuthService] Saved uiLanguage: $uiLanguage');
      
      return {'success': true, 'autoSelected': true};
    } else {
      // Return stores for selection
      return {
        'success': true, 
        'autoSelected': false, 
        'stores': result['stores']
      };
    }
  }

  Future<Map<String, dynamic>> selectPos({
    required String email,
    required String storeId,
    required String posId,
    String? deviceId,
  }) async {
    final result = await _api.selectPos(
      email: email,
      storeId: storeId,
      posId: posId,
      deviceId: deviceId,
    );
    
    final accessToken = result['accessToken'] as String?;
    final uiLanguage = result['uiLanguage'] as String?;
    
    print('[PosAuthService] selectPos response - uiLanguage: $uiLanguage');
    
    if (accessToken == null) {
      throw Exception('응답 형식이 올바르지 않습니다.');
    }

    await _storage.saveSession(
      accessToken: accessToken,
      storeId: storeId,
      posId: posId,
      storeName: result['storeName'],
      storeBizNo: result['businessNumber'],
      storeAddr: result['address'],
      storePhone: result['phone'],
      uiLanguage: uiLanguage,
    );
    
    print('[PosAuthService] Saved uiLanguage: $uiLanguage');
    
    return result;
  }

  Future<bool> verifyToken() async {
    final token = await _storage.getAccessToken();
    if (token == null) return false;
    
    final isValid = await _api.verifyToken(token);
    if (!isValid) {
      await _storage.clear();
    }
    return isValid;
  }
}

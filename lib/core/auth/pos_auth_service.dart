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
    );
  }

  Future<void> loginAsOwner(String email, String password) async {
    final result = await _api.loginAsOwner(email, password);
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
    );
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

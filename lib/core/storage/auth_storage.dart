import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'pos_access_token';
  static const _storeIdKey = 'pos_store_id';
  static const _posIdKey = 'pos_id';

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<void> saveSession({
    required String accessToken,
    required String storeId,
    required String posId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_storeIdKey, storeId);
    await prefs.setString(_posIdKey, posId);
  }

  Future<Map<String, String?>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessToken': prefs.getString(_accessTokenKey),
      'storeId': prefs.getString(_storeIdKey),
      'posId': prefs.getString(_posIdKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_storeIdKey);
    await prefs.remove(_posIdKey);
  }
}

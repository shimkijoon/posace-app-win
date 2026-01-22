import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'pos_access_token';
  static const _storeIdKey = 'pos_store_id';
  static const _posIdKey = 'pos_id';
  static const _storeNameKey = 'pos_store_name';
  static const _storeBizNoKey = 'pos_store_biz_no';
  static const _storeAddrKey = 'pos_store_addr';
  static const _storePhoneKey = 'pos_store_phone';

  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessTokenKey);
  }

  Future<void> saveSession({
    required String accessToken,
    required String storeId,
    required String posId,
    String? storeName,
    String? storeBizNo,
    String? storeAddr,
    String? storePhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_storeIdKey, storeId);
    await prefs.setString(_posIdKey, posId);
    if (storeName != null) await prefs.setString(_storeNameKey, storeName);
    if (storeBizNo != null) await prefs.setString(_storeBizNoKey, storeBizNo);
    if (storeAddr != null) await prefs.setString(_storeAddrKey, storeAddr);
    if (storePhone != null) await prefs.setString(_storePhoneKey, storePhone);
  }

  Future<Map<String, String?>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessToken': prefs.getString(_accessTokenKey),
      'storeId': prefs.getString(_storeIdKey),
      'posId': prefs.getString(_posIdKey),
      'name': prefs.getString(_storeNameKey),
      'businessNumber': prefs.getString(_storeBizNoKey),
      'address': prefs.getString(_storeAddrKey),
      'phone': prefs.getString(_storePhoneKey),
    };
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_storeIdKey);
    await prefs.remove(_posIdKey);
    await prefs.remove(_storeNameKey);
    await prefs.remove(_storeBizNoKey);
    await prefs.remove(_storeAddrKey);
    await prefs.remove(_storePhoneKey);
  }
}

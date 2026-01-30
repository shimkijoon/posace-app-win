import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const _accessTokenKey = 'pos_access_token';
  static const _storeIdKey = 'pos_store_id';
  static const _posIdKey = 'pos_id';
  static const _storeNameKey = 'pos_store_name';
  static const _storeBizNoKey = 'pos_store_biz_no';
  static const _storeAddrKey = 'pos_store_addr';
  static const _storePhoneKey = 'pos_store_phone';
  static const _uiLanguageKey = 'pos_ui_language';
  static const _employeeIdKey = 'pos_employee_id';
  static const _sessionIdKey = 'pos_session_id';
  static const _saleShowBarcodeInGridKey = 'pos_sale_show_barcode_in_grid';

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
    String? uiLanguage,
    bool? saleShowBarcodeInGrid,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessTokenKey, accessToken);
    await prefs.setString(_storeIdKey, storeId);
    await prefs.setString(_posIdKey, posId);
    if (storeName != null) await prefs.setString(_storeNameKey, storeName);
    if (storeBizNo != null) await prefs.setString(_storeBizNoKey, storeBizNo);
    if (storeAddr != null) await prefs.setString(_storeAddrKey, storeAddr);
    if (storePhone != null) await prefs.setString(_storePhoneKey, storePhone);
    if (uiLanguage != null) await prefs.setString(_uiLanguageKey, uiLanguage);
    if (saleShowBarcodeInGrid != null) {
      await prefs.setBool(_saleShowBarcodeInGridKey, saleShowBarcodeInGrid);
    }
  }

  Future<Map<String, dynamic>> getSessionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'accessToken': prefs.getString(_accessTokenKey),
      'storeId': prefs.getString(_storeIdKey),
      'posId': prefs.getString(_posIdKey),
      'name': prefs.getString(_storeNameKey),
      'businessNumber': prefs.getString(_storeBizNoKey),
      'address': prefs.getString(_storeAddrKey),
      'phone': prefs.getString(_storePhoneKey),
      'uiLanguage': prefs.getString(_uiLanguageKey),
      'employeeId': prefs.getString(_employeeIdKey),
      'sessionId': prefs.getString(_sessionIdKey),
      'saleShowBarcodeInGrid': prefs.getBool(_saleShowBarcodeInGridKey),
    };
  }

  Future<String?> getUiLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_uiLanguageKey);
  }

  Future<void> saveEmployee(String? employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    if (employeeId == null) {
      await prefs.remove(_employeeIdKey);
    } else {
      await prefs.setString(_employeeIdKey, employeeId);
    }
  }

  Future<void> savePosSession(String? sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    if (sessionId == null) {
      await prefs.remove(_sessionIdKey);
    } else {
      await prefs.setString(_sessionIdKey, sessionId);
    }
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
    await prefs.remove(_uiLanguageKey);
    await prefs.remove(_saleShowBarcodeInGridKey);
  }
}

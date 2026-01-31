import '../../core/storage/auth_storage.dart';
import '../../data/remote/pos_auth_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

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
      saleShowBarcodeInGrid: result['saleShowBarcodeInGrid'] as bool?,
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
      final saleShowBarcodeInGrid = result['saleShowBarcodeInGrid'] as bool?;

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
        saleShowBarcodeInGrid: saleShowBarcodeInGrid,
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

  Future<Map<String, dynamic>> loginWithGoogle() async {
    try {
      // 1. Google Login via Supabase (Opens Browser)
      
      final client = supabase.Supabase.instance.client;
      await client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'posace://login-callback',
      );
      
      return {'initiated': true};
    } catch (e) {
      throw Exception('Google 로그인 시작 실패: $e');
    }
  }
  
  // This method is called AFTER the deep link has processed the session
  Future<Map<String, dynamic>> completeSocialLogin() async {
     final client = supabase.Supabase.instance.client;
     final session = client.auth.currentSession;
     if (session == null) throw Exception('No active session');
     
     final user = session.user;
     final userId = user.id;
     final email = user.email; // might be null
     
     final stores = await client
         .from('stores')
         .select('id, name, address, business_number')
         .eq('owner_id', userId); // or appropriate column
         
     final mappedStores = (stores as List).map((s) => {
       'id': s['id'],
       'name': s['name'],
       'address': s['address'],
       'businessNumber': s['business_number'],
     }).toList();
     
     return {
        'success': true, 
        'autoSelected': false, 
        'stores': mappedStores,
        'email': email,
        'userId': userId
      };
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
    final saleShowBarcodeInGrid = result['saleShowBarcodeInGrid'] as bool?;
    
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
      saleShowBarcodeInGrid: saleShowBarcodeInGrid,
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

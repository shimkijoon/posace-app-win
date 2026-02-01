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
    // Try Supabase Auth first (for Web-created accounts)
    try {
      final client = supabase.Supabase.instance.client;
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user != null) {
        // Supabase Login Success
        print('[PosAuthService] Supabase login success for ${user.email}');
        
        // Fetch stores with POS devices
        final stores = await client
            .from('stores')
            .select('id, name, address, businessNumber, phone, language, country, ownerId, posDevices:pos_devices(id, name, deviceId, type, status)')
            .eq('ownerId', user.id)
            .eq('isDeleted', false); 
            
        // Map to expected format
        final mappedStores = (stores as List).map((s) => {
          'id': s['id'],
          'name': s['name'],
          'address': s['address'],
          'businessNumber': s['businessNumber'],
          'phone': s['phone'],
          'posDevices': (s['posDevices'] as List?)?.map((p) => {
            'id': p['id'],
            'name': p['name'],
            'deviceId': p['deviceId'],
            'type': p['type'],
            'status': p['status'],
          }).toList() ?? [],
        }).toList();
        
        // Check for saved preferred store/POS
        final preferredStoreId = await _storage.getPreferredStore();
        final preferredPosId = await _storage.getPreferredPos();
        
        if (preferredStoreId != null && preferredPosId != null) {
          // Try to find the preferred store and POS
          final preferredStore = mappedStores.cast<Map<String, dynamic>>().firstWhere(
            (store) => store['id'] == preferredStoreId,
            orElse: () => {},
          );
          
          if (preferredStore.isNotEmpty) {
            final posDevices = preferredStore['posDevices'] as List<dynamic>? ?? [];
            final preferredPos = posDevices.cast<Map<String, dynamic>>().firstWhere(
              (pos) => pos['id'] == preferredPosId,
              orElse: () => {},
            );
            
            if (preferredPos.isNotEmpty) {
              // Auto-select the preferred store/POS
              print('[PosAuthService] Auto-selecting preferred store: ${preferredStore['name']}, POS: ${preferredPos['name']}');
              
              try {
                await selectPos(
                  email: user.email!,
                  storeId: preferredStoreId,
                  posId: preferredPosId,
                  deviceId: deviceId,
                );
                
                return {
                  'success': true,
                  'autoSelected': true,
                  'email': user.email,
                };
              } catch (e) {
                print('[PosAuthService] Auto-selection failed: $e, clearing preferences');
                await _storage.clearPreferredSelections();
                // Fall through to manual selection
              }
            } else {
              print('[PosAuthService] Preferred POS not found, clearing preferences');
              await _storage.clearPreferredSelections();
            }
          } else {
            print('[PosAuthService] Preferred store not found, clearing preferences');
            await _storage.clearPreferredSelections();
          }
        }
        
        // Return result compatible with LoginPage expectations
        // Note: Auto-selection logic is simplified here; we just return list.
        return {
           'success': true, 
           'autoSelected': false,
           'stores': mappedStores,
           'email': user.email,
        };
      }
    } catch (e) {
      print('[PosAuthService] Supabase login failed: $e');
      // Fallback to Legacy API login (for old accounts or if Supabase Auth isn't used for them)
      // If the error confirms "Invalid login credentials", we might still want to try API?
      // But actually, mixing two auth sources with same email is confusing.
      // If the user says "Web account", Supabase is the one.
      // Let's just throw for now, or try API as fallback.
      // The user wants "fix", so Supabase is priority.
      
      // Attempt legacy API login as fallback
      try {
         final result = await _api.loginAsOwner(email, password, deviceId: deviceId);
         
         // If API succeeds (e.g. old local account), return it.
         // But need to handle saving session inside `loginAsOwner` if standard API?
         // The original code handled session saving inside `loginAsOwner`.
         // We should probably keep that logic for API path.
         
         // Let's re-use the original logic for the API part.
         // Original logic:
         final bool autoSelected = result['autoSelected'] ?? false;
         if (autoSelected) {
            // ... saving session ... (copied from original)
            final accessToken = result['accessToken'] as String?;
            final storeId = result['storeId'] as String?;
            final posId = result['posId'] as String?;
            final uiLanguage = result['uiLanguage'] as String?;
            final saleShowBarcodeInGrid = result['saleShowBarcodeInGrid'] as bool?;

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
            return {'success': true, 'autoSelected': true};
         } else {
            return {
              'success': true, 
              'autoSelected': false, 
              'stores': result['stores']
            };
         }
      } catch (apiError) {
         // Both failed
         throw Exception('로그인 실패: 이메일 또는 비밀번호를 확인해주세요.');
      }
    }
    
    throw Exception('로그인 실패');
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

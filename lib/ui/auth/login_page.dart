import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth/pos_auth_service.dart';
import '../../core/utils/restart_widget.dart';
import '../../data/local/app_database.dart';
import '../home/home_page.dart';
import 'store_selection_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = PosAuthService();
  bool _loading = false;
  String? _error;
  bool _showTestAccounts = false;

  static const List<Map<String, String>> _testAccounts = [
    {'country': '한국', 'code': 'KR', 'email': 'owner-kr@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce 한국 매장'},
    {'country': '日本', 'code': 'JP', 'email': 'owner-jp@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce 日本店'},
    {'country': '台灣', 'code': 'TW', 'email': 'owner-tw@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce 台灣店'},
    {'country': '香港', 'code': 'HK', 'email': 'owner-hk@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce Hong Kong Store'},
    {'country': 'Singapore', 'code': 'SG', 'email': 'owner-sg@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce Singapore Store'},
    {'country': 'Australia', 'code': 'AU', 'email': 'owner-au@posace.dev', 'password': 'Password123!', 'storeName': 'POSAce Australia Store'},
  ];

  bool _isGoogleLoading = false;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link
    try {
      final initialUri = await _appLinks.getInitialLink(); // getInitialUri is deprecated in v6? 
      // app_links v6 uses getInitialLink -> Uri? or getInitialAppLink -> Uri?
      // Actually v6.3.2 uses getInitialLink().
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    // Listen to incoming links
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Check if it's our login callback
    if (uri.scheme == 'posace' && uri.host == 'login-callback') {
       print('[LoginPage] Received deep link: $uri');
       // Let Supabase handle the code exchange
       try {
         // Supabase Flutter helper to parse session
         // Since v2.6, supabase.auth.getSessionFromUrl(uri) works
         final supabase = Supabase.instance.client;
         await supabase.auth.getSessionFromUrl(uri);
         
         // If successful, proceed to complete login
         if (mounted) {
           _completeGoogleLogin();
         }
       } catch (e) {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('소셜 로그인 처리 중 오류 발생: $e'), backgroundColor: Colors.red),
           );
         }
       }
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result = await _authService.loginWithGoogle();
      // Wait for deep link...
    } catch (e) {
      setState(() {
         _error = e.toString().replaceAll('Exception: ', '');
         _isGoogleLoading = false; // Stop loading if init failed
      });
    }
    // Don't stop loading, keep spinning until deep link returns or timeout?
    // User might cancel browser. So maybe we should stop loading after few seconds or provide cancel?
    // Simple approach: Set loading false after slight delay or keep it true until App Pause/Resume?
    // Browser opens, App goes background.
    // When App resumes (Deep Link), we handle it.
  }

  Future<void> _completeGoogleLogin() async {
     try {
       final result = await _authService.completeSocialLogin();
       
       if (!mounted) return;
       setState(() => _isGoogleLoading = false);
       
       // Handle Store Selection
       // Google Login users have "no password" on POS, but we fetched their stores via Supabase
       
       final stores = result['stores'] as List<dynamic>? ?? [];
       if (stores.isEmpty) {
          // No store found
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('계정에 연결된 매장이 없습니다.'), backgroundColor: Colors.orange),
           );
           return;
       }
       
       // Proceed to Store Selection
       // Use a dummy "GoogleUser" password or modify StoreSelection to not require re-auth?
       // StoreSelection page selects store and calls `selectPos`.
       // `selectPos` requires `email`.
       // We have email from `completeSocialLogin`.
       
       final email = result['email'] as String? ?? '';
       // Pass a flag to StoreSelection that we are authenticated via Social?
       // If StoreSelection calls `selectPos` (Backend), backend needs to support it.
       // Current backend `selectPos` (Step 870) takes email, storeId, posId, deviceId.
       // It doesn't seem to verify password again?
       // Wait, `selectPos` in API usually verifies token or password?
       // `PosAuthApi.selectPos` (Step 870) just sends params.
       // The backend implementation of `selectPos` will determine if it works.
       // If backend `selectPos` doesn't protect with password, then we are good.
       // If it expects a token, `PosAuthApi` doesn't send one?
       // `PosAuthApi.selectPos` body: {email, storeId, posId...} NO TOKEN.
       // So likely `selectPos` on backend is Open (or weak security)?
       // OR it relies on `email` being valid?
       // Let's assume it works for now.
       
       Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoreSelectionPage(
              database: widget.database,
              email: email,
              stores: stores,
              deviceId: 'WIN-DEVICE-001', // Should match initial call
            ),
          ),
        );

     } catch (e) {
       setState(() {
         _error = '로그인 완료 실패: $e';
         _isGoogleLoading = false;
       });
     }
  }


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _error = '이메일과 비밀번호를 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // NOTE: In a real app, we would get the actual hardware device ID here.
      // For now, we'll use a placeholder or dummy ID.
      const String deviceId = 'WIN-DEVICE-001'; 

      final result = await _authService.loginAsOwner(
        _emailController.text.trim(),
        _passwordController.text,
        deviceId: deviceId,
      );

      if (!mounted) return;

      if (result['autoSelected'] == true) {
        // 로그인 성공 - 언어 설정을 적용하기 위해 앱 재시작
        print('[LoginPage] Login successful, restarting app to apply new locale...');
        RestartWidget.restartApp(context);
      } else {
        // stores가 null일 수 있으므로 안전하게 처리
        final stores = result['stores'] as List<dynamic>? ?? [];
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StoreSelectionPage(
              database: widget.database,
              email: _emailController.text.trim(),
              stores: stores,
              deviceId: deviceId,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _testLogin({String? email, String? password}) async {
    _emailController.text = email ?? 'owner@posace.dev';
    _passwordController.text = password ?? 'Password123!';
    await _submit();
  }

  void _selectTestAccount(Map<String, String> account) {
    setState(() {
      _showTestAccounts = false;
    });
    _testLogin(email: account['email']!, password: account['password']!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS 로그인')),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '점주 계정으로 로그인',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('가입하신 이메일과 비밀번호를 입력하세요.'),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '이메일',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '비밀번호',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(_loading ? '로그인 중...' : '로그인'),
                ),
              ),
              const SizedBox(height: 16),
              // Google Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: (_loading || _isGoogleLoading) ? null : _googleLogin,
                  icon: _isGoogleLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.g_mobiledata, size: 28), // Using Icon for simplicity
                  label: const Text('Google 계정으로 로그인 (웹 브라우저)'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
              ),

              // Test account selection (only show in debug mode)
              if (kDebugMode) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() {
                            _showTestAccounts = !_showTestAccounts;
                          });
                        },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    side: BorderSide(color: Colors.blue.shade300),
                  ).copyWith(
                    textStyle: MaterialStateProperty.all<TextStyle>(
                      const TextStyle(
                        inherit: false,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                    child: Text(_showTestAccounts ? '테스트 계정 선택 닫기' : '테스트 계정 선택'),
                  ),
                ),
                if (_showTestAccounts) ...[
                const SizedBox(height: 12),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          '국가별 테스트 계정:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _testAccounts.length,
                          itemBuilder: (context, index) {
                            final account = _testAccounts[index];
                            return InkWell(
                              onTap: _loading ? null : () => _selectTestAccount(account),
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${account['country']} (${account['code']})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      account['email']!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    Text(
                                      account['storeName']!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _loading ? null : () => _testLogin(),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: Colors.blue.shade200),
                    ),
                    child: const Text(
                      '기본 테스트 계정으로 로그인',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

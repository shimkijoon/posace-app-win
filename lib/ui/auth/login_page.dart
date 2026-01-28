import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    // Pre-fill with sample account for convenience if needed, 
    // but better to leave empty or use the Test Login button.
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
              // Test account selection (always show in development)
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
          ),
        ),
      ),
    );
  }
}

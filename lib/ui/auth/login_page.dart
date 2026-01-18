import 'package:flutter/material.dart';
import '../../core/auth/pos_auth_service.dart';
import '../../data/local/app_database.dart';
import '../home/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _deviceTokenController = TextEditingController();
  final _authService = PosAuthService();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _deviceTokenController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.loginWithDeviceToken(_deviceTokenController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomePage(database: widget.database)),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS 로그인')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('디바이스 토큰을 입력하세요.'),
            const SizedBox(height: 12),
            TextField(
              controller: _deviceTokenController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Device Token',
              ),
              minLines: 1,
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: Text(_loading ? '로그인 중...' : '로그인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

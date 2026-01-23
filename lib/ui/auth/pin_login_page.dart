import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_employees_api.dart';
import '../../data/local/app_database.dart';
import '../home/home_page.dart';
import '../../core/theme/app_theme.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String _pin = '';
  bool _isLoading = false;
  String? _error;

  void _onKeyPress(String key) {
    if (_pin.length < 6) {
      setState(() {
        _pin += key;
        _error = null;
      });
    }

    if (_pin.length >= 4) {
      // Auto-submit could be an option, but let's use a Confirm button or explicit check
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _submit() async {
    if (_pin.length < 4) return;

    setState(() => _isLoading = true);
    try {
      final auth = AuthStorage();
      final session = await auth.getSessionInfo();
      final token = await auth.getAccessToken();
      final storeId = session['storeId'];

      if (storeId == null || token == null) throw Exception('인증 정보가 없습니다. 다시 로그인해주세요.');

      final apiClient = ApiClient(baseUrl: '', accessToken: token); // Base URL will be handled by buildUri
      final api = PosEmployeesApi(apiClient);
      
      final employee = await api.verifyPin(storeId, _pin);
      
      await auth.saveEmployee(employee.id);
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomePage(database: widget.database)),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'PIN 번호가 올바르지 않습니다.';
        _pin = '';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '직원 로그인',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('PIN 번호를 입력하세요'),
              const SizedBox(height: 40),
              
              // PIN Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length ? AppTheme.primary : Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                  );
                }),
              ),
              
              const SizedBox(height: 20),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              
              const SizedBox(height: 40),
              
              // Keypad
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.5,
                children: [
                  ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map((key) {
                    return _buildKey(key);
                  }),
                  _buildKey('C', color: Colors.orange.shade100, onPressed: () => setState(() => _pin = '')),
                  _buildKey('0'),
                  _buildKey('⌫', color: Colors.grey.shade200, onPressed: _onBackspace),
                ],
              ),
              
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _pin.length >= 4 && !_isLoading ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('확인', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String label, {Color? color, VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed ?? () => _onKeyPress(label),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

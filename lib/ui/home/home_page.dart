import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../auth/login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = AuthStorage();
  Map<String, String?> _session = {};

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final session = await _storage.getSessionInfo();
    if (!mounted) return;
    setState(() {
      _session = session;
    });
  }

  Future<void> _logout() async {
    await _storage.clear();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POSAce Windows'),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text('로그아웃'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('POSAce Windows Client'),
            const SizedBox(height: 12),
            Text('Store ID: ${_session['storeId'] ?? '-'}'),
            Text('POS ID: ${_session['posId'] ?? '-'}'),
          ],
        ),
      ),
    );
  }
}

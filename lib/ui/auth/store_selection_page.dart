import 'package:flutter/material.dart';
import '../../core/auth/pos_auth_service.dart';
import '../../core/utils/restart_widget.dart';
import '../../data/local/app_database.dart';
import '../home/home_page.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({
    super.key,
    required this.database,
    required this.email,
    required this.stores,
    this.deviceId,
  });

  final AppDatabase database;
  final String email;
  final List<dynamic> stores;
  final String? deviceId;

  @override
  State<StoreSelectionPage> createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  final _authService = PosAuthService();
  Map<String, dynamic>? _selectedStore;
  bool _loading = false;

  Future<void> _onSelectPos(Map<String, dynamic> pos) async {
    setState(() => _loading = true);
    try {
      final result = await _authService.selectPos(
        email: widget.email,
        storeId: _selectedStore!['id'],
        posId: pos['id'],
        deviceId: widget.deviceId,
      );
      if (!mounted) return;
      
      // POS 선택 성공 - 언어 설정을 적용하기 위해 앱 재시작
      print('[StoreSelectionPage] POS selected successfully, restarting app to apply new locale...');
      RestartWidget.restartApp(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedStore == null ? '매장 선택' : 'POS 기기 선택'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(32),
          child: _loading 
            ? const CircularProgressIndicator()
            : _selectedStore == null 
              ? _buildStoreList() 
              : _buildPosList(),
        ),
      ),
    );
  }

  Widget _buildStoreList() {
    // stores가 null이거나 비어있는 경우 처리
    final stores = widget.stores ?? [];
    
    if (stores.isEmpty) {
      return const Center(
        child: Text('등록된 매장이 없습니다.'),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '접속할 매장을 선택하세요',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...stores.map((store) {
          // posDevices가 null일 수 있으므로 안전하게 처리
          final posDevices = store['posDevices'] as List<dynamic>? ?? [];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                store['name']?.toString() ?? '이름 없음',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('POS 기기: ${posDevices.length}대'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => setState(() => _selectedStore = store as Map<String, dynamic>),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildPosList() {
    // posDevices가 null일 수 있으므로 안전하게 처리
    final posDevices = (_selectedStore!['posDevices'] as List<dynamic>?) ?? [];
    
    if (posDevices.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_selectedStore!['name']}의 POS 기기 선택',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          const Text('등록된 POS 기기가 없습니다.'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _selectedStore = null),
            child: const Text('매장 다시 선택'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_selectedStore!['name']}의 POS 기기 선택',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...posDevices.map((pos) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.computer),
            title: Text(
              pos['name']?.toString() ?? '이름 없음',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: pos['deviceId'] != null 
                ? Text('연결된 기기: ${pos['deviceId']}') 
                : const Text('새 기기 연결 가능'),
            trailing: const Icon(Icons.check_circle_outline),
            onTap: () => _onSelectPos(pos as Map<String, dynamic>),
          ),
        )),
        TextButton(
          onPressed: () => setState(() => _selectedStore = null),
          child: const Text('매장 다시 선택'),
        ),
      ],
    );
  }
}

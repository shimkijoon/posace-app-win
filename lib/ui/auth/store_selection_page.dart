import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/pos_auth_service.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/utils/restart_widget.dart';
import '../../data/local/app_database.dart';
import '../../core/i18n/app_localizations.dart';
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
  final _authStorage = AuthStorage();
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
      
      // Save preferred store and POS selections
      await _authStorage.savePreferredStore(_selectedStore!['id']);
      await _authStorage.savePreferredPos(pos['id']);
      
      // POS 선택 성공 - 홈 화면으로 이동
      print('[StoreSelectionPage] POS selected successfully, saved preferences, navigating to home...');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomePage(database: widget.database),
        ),
      );
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
        title: Text(_selectedStore == null ? AppLocalizations.of(context)!.translate('auth.selectStore') ?? '매장 선택' : AppLocalizations.of(context)!.translate('auth.selectPos') ?? 'POS 기기 선택'),
      ),
      body: Center(
        child: SingleChildScrollView(
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
      ),
    );
  }

  Widget _buildStoreList() {
    // stores가 null이거나 비어있는 경우 처리
    final stores = widget.stores ?? [];
    
    
    if (stores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              '등록된 매장이 없습니다',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              '백오피스에서 매장을 먼저 생성해주세요.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        '매장 생성 안내',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '1. 백오피스(${AppConfig.backofficeBaseUrl})에 접속\n'
                    '2. 동일한 계정으로 로그인\n'
                    '3. "매장 생성" 메뉴 선택\n'
                    '4. 매장 유형 선택 (카페, 레스토랑 등)\n'
                    '5. 샘플 데이터 자동 생성 옵션 선택',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        // Open backoffice in browser
                        final uri = Uri.parse('${AppConfig.backofficeBaseUrl}/stores/new');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('백오피스에서 매장 생성하기'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('auth.selectStorePrompt') ?? '접속할 매장을 선택하세요',
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
                store['name']?.toString() ?? AppLocalizations.of(context)!.translate('auth.noName') ?? '이름 없음',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(AppLocalizations.of(context)!.translate('auth.posDeviceCount')?.replaceAll('{count}', posDevices.length.toString()) ?? 'POS 기기: ${posDevices.length}대'),
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
            AppLocalizations.of(context)!.translate('auth.selectPosForStore')?.replaceAll('{storeName}', _selectedStore!['name']?.toString() ?? '') ?? '${_selectedStore!['name']}의 POS 기기 선택',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.translate('auth.noPosDevices') ?? '등록된 POS 기기가 없습니다.'),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => setState(() => _selectedStore = null),
            child: Text(AppLocalizations.of(context)!.translate('auth.reselectStore') ?? '매장 다시 선택'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('auth.selectPosForStore')?.replaceAll('{storeName}', _selectedStore!['name']?.toString() ?? '') ?? '${_selectedStore!['name']}의 POS 기기 선택',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        ...posDevices.map((pos) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.computer),
            title: Text(
              pos['name']?.toString() ?? AppLocalizations.of(context)!.translate('auth.noName') ?? '이름 없음',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: pos['deviceId'] != null 
                ? Text(AppLocalizations.of(context)!.translate('auth.connectedDevice')?.replaceAll('{deviceId}', pos['deviceId'].toString()) ?? '연결된 기기: ${pos['deviceId']}') 
                : Text(AppLocalizations.of(context)!.translate('auth.canConnectNewDevice') ?? '새 기기 연결 가능'),
            trailing: const Icon(Icons.check_circle_outline),
            onTap: () => _onSelectPos(pos as Map<String, dynamic>),
          ),
        )),
        TextButton(
          onPressed: () => setState(() => _selectedStore = null),
          child: Text(AppLocalizations.of(context)!.translate('auth.reselectStore') ?? '매장 다시 선택'),
        ),
      ],
    );
  }
}

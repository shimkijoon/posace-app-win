import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/printer/serial_printer_service.dart';
import '../../core/printer/esc_pos_encoder.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/pos_master_api.dart';
import '../../data/remote/pos_sales_api.dart';
import '../../sync/sync_service.dart';
import '../sales/widgets/title_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.database});

  final AppDatabase database;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _printerService = SerialPrinterService();
  final _settingsStorage = SettingsStorage();
  final _authStorage = AuthStorage();
  
  List<String> _availablePorts = [];
  final List<int> _baudRates = [9600, 19200, 38400, 57600, 115200];

  String? _receiptPort;
  int _receiptBaudInt = 9600;
  String? _kitchenPort;
  int _kitchenBaud = 9600;
  bool _usePosSession = true;
  
  bool _syncing = false;
  String? _syncStatus;
  int _categoriesCount = 0;
  int _productsCount = 0;
  int _discountsCount = 0;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final ports = _printerService.getAvailablePorts();
    
    final rPort = await _settingsStorage.getReceiptPrinterPort();
    final rBaud = await _settingsStorage.getReceiptPrinterBaud();
    final kPort = await _settingsStorage.getKitchenPrinterPort();
    final kBaud = await _settingsStorage.getKitchenPrinterBaud();
    final useSession = await _settingsStorage.getUsePosSession(); // Load new setting
    
    setState(() {
      _availablePorts = ports;
      _receiptPort = (rPort != null && ports.contains(rPort)) ? rPort : null;
      _receiptBaudInt = rBaud; // Use _receiptBaudInt
      _kitchenPort = (kPort != null && ports.contains(kPort)) ? kPort : null;
      _kitchenBaud = kBaud;
      _usePosSession = useSession; // Set new state
      _isLoading = false;
    });
    
    await _loadDataCounts();
  }

  Future<void> _saveSettings() async {
    await _settingsStorage.setUsePosSession(_usePosSession); // Save new setting

    if (_receiptPort != null) {
      await _settingsStorage.setReceiptPrinterPort(_receiptPort!);
      await _settingsStorage.setReceiptPrinterBaud(_receiptBaudInt); // Use _receiptBaudInt
      _printerService.connect(_receiptPort!, baudRate: _receiptBaudInt); // Use _receiptBaudInt
    }
    
    if (_kitchenPort != null) {
      await _settingsStorage.setKitchenPrinterPort(_kitchenPort!);
      await _settingsStorage.setKitchenPrinterBaud(_kitchenBaud);
      _printerService.connect(_kitchenPort!, baudRate: _kitchenBaud);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다.')),
      );
    }
  }

  Future<void> _testPrint(String type) async {
    String? port = type == 'receipt' ? _receiptPort : _kitchenPort;
    int baud = type == 'receipt' ? _receiptBaudInt : _kitchenBaud;
    final title = type == 'receipt' ? 'Receipt Printer' : 'Kitchen Printer';

    if (port == null) {
      print('SettingsPage: Test print failed - No port selected for $title');
      return;
    }
    
    print('SettingsPage: Starting test print for $title on $port');
    if (!_printerService.isConnected(port)) {
        print('SettingsPage: Port $port not connected. Attempting connection...');
        _printerService.connect(port, baudRate: baud);
    }

    if (_printerService.isConnected(port)) {
        try {
            final encoder = EscPosEncoder();
            encoder.reset();
            encoder.setAlign('center');
            await encoder.text('*** $title ***', bold: true, doubleHeight: true, doubleWidth: true);
            encoder.lineFeed(1);
            await encoder.text('Test Print Successful!', align: 'center');
            encoder.lineFeed();
            await encoder.text('포스에이스 프린트 테스트', align: 'center');
            encoder.lineFeed(2);
            encoder.cut();
            
            final bytes = encoder.bytes;
            print('SettingsPage: Sending ${bytes.length} bytes to $port');
            await _printerService.printBytes(port, bytes);
        } catch (e) {
            print('SettingsPage: Test print error: $e');
        }
    } else {
        print('SettingsPage: Failed to connect to $port for test print.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title 연결에 실패했습니다.')),
          );
        }
    }
  }

  Future<void> _loadDataCounts() async {
    final categories = await widget.database.getCategories();
    final products = await widget.database.getProducts();
    final discounts = await widget.database.getDiscounts();
    
    if (!mounted) return;
    setState(() {
      _categoriesCount = categories.length;
      _productsCount = products.length;
      _discountsCount = discounts.length;
    });
  }

  Future<void> _syncMaster() async {
    final accessToken = await _authStorage.getAccessToken();
    final sessionInfo = await _authStorage.getSessionInfo();
    final storeId = sessionInfo['storeId'];
    
    if (storeId == null || accessToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다.')),
      );
      return;
    }

    setState(() {
      _syncing = true;
      _syncStatus = '동기화 중...';
    });

    try {
      final apiClient = ApiClient(accessToken: accessToken);
      final masterApi = PosMasterApi(apiClient);
      final salesApi = PosSalesApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: salesApi,
      );

      final result = await syncService.syncMaster(
        storeId: storeId,
        manual: true,
      );

      int uploadedCount = 0;
      if (result.success) {
        uploadedCount = await syncService.flushSalesQueue();
      }

      if (!mounted) return;

      if (result.success) {
        await _settingsStorage.setLastSyncAt(DateTime.now());
        await _loadDataCounts();
        setState(() {
          _syncStatus = '동기화 완료';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '동기화 완료: 마스터(${result.productsCount ?? 0}개), 매출($uploadedCount건) 업로드',
            ),
          ),
        );
      } else {
        setState(() {
          _syncStatus = '동기화 실패: ${result.error}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('동기화 실패: ${result.error}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '동기화 오류: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('동기화 오류: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  Future<void> _resetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('데이터 초기화'),
        content: const Text('로컬의 모든 데이터를 삭제하고 서버에서 다시 불러오시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('예, 초기화합니다'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _syncing = true;
      _syncStatus = '데이터 초기화 중...';
    });

    try {
      final accessToken = await _authStorage.getAccessToken();
      final apiClient = ApiClient(accessToken: accessToken!);
      final masterApi = PosMasterApi(apiClient);
      final salesApi = PosSalesApi(apiClient);
      final syncService = SyncService(
        database: widget.database,
        masterApi: masterApi,
        salesApi: salesApi,
      );

      await syncService.clearLocalData();
      await _syncMaster();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _syncStatus = '초기화 오류: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('초기화 중 오류 발생: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          TitleBar(
            title: AppLocalizations.of(context)!.translate('settings.title'),
            onHomePressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSection(
                      title: AppLocalizations.of(context)!.translate('settings.general'),
                      children: [
                        SwitchListTile(
                          title: Text(AppLocalizations.of(context)!.translate('settings.sessionFeature')),
                          subtitle: Text(AppLocalizations.of(context)!.translate('settings.sessionFeatureDesc')),
                          value: _usePosSession,
                          onChanged: (val) => setState(() => _usePosSession = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPrinterSection(
                      title: AppLocalizations.of(context)!.translate('settings.receiptPrinter'),
                      portValue: _receiptPort,
                      baudValue: _receiptBaudInt, // Fix variable name
                      onPortChanged: (val) => setState(() => _receiptPort = val),
                      onBaudChanged: (val) => setState(() => _receiptBaudInt = val ?? 9600),
                      onTestPrint: () => _testPrint('receipt'),
                    ),
                    const SizedBox(height: 24),
                    _buildPrinterSection(
                      title: AppLocalizations.of(context)!.translate('settings.kitchenPrinter'),
                      portValue: _kitchenPort,
                      baudValue: _kitchenBaud,
                      onPortChanged: (val) => setState(() => _kitchenPort = val),
                      onBaudChanged: (val) => setState(() => _kitchenBaud = val ?? 9600),
                      onTestPrint: () => _testPrint('kitchen'),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: '데이터 관리',
                      children: [
                        if (_syncStatus != null) ...[
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _syncStatus!,
                              style: TextStyle(
                                color: _syncStatus!.contains('완료') ? AppTheme.success : (_syncStatus!.contains('실패') || _syncStatus!.contains('오류') ? AppTheme.error : AppTheme.textSecondary),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('카테고리: $_categoriesCount개', style: const TextStyle(fontSize: 13)),
                                    Text('상품: $_productsCount개', style: const TextStyle(fontSize: 13)),
                                    Text('할인: $_discountsCount개', style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _syncing ? null : _syncMaster,
                                    icon: _syncing
                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Icon(Icons.sync, size: 18),
                                    label: const Text('동기화'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: _syncing ? null : _resetData,
                                    icon: const Icon(Icons.refresh, color: AppTheme.error, size: 18),
                                    label: const Text('초기화', style: TextStyle(color: AppTheme.error)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primary,
                      ),
                      child: const Text('설정 저장', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildPrinterSection({
    required String title,
    required String? portValue,
    required int baudValue,
    required ValueChanged<String?> onPortChanged,
    required ValueChanged<int?> onBaudChanged,
    required VoidCallback onTestPrint,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          ListTile(
            title: Text(AppLocalizations.of(context)!.translate('settings.serialPort')),
            trailing: DropdownButton<String>(
              value: portValue,
              items: _availablePorts.map((port) => DropdownMenuItem(value: port, child: Text(port))).toList(),
              onChanged: onPortChanged,
              hint: Text(AppLocalizations.of(context)!.translate('common.select') ?? '선택'),
            ),
          ),
          ListTile(
            title: Text(AppLocalizations.of(context)!.translate('settings.baudRate')),
            trailing: DropdownButton<int>(
              value: baudValue,
              items: _baudRates.map((baud) => DropdownMenuItem(value: baud, child: Text(baud.toString()))).toList(),
              onChanged: onBaudChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: onTestPrint,
              child: Text(AppLocalizations.of(context)!.translate('settings.testPrint')),
            ),
          ),
        ],
      ),
    );
  }
}

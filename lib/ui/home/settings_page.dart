import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/printer/serial_printer_service.dart';
import '../../core/printer/esc_pos_encoder.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/printer/printer_manager.dart';
import '../../core/printer/network_printer_driver.dart';
import '../../core/printer/windows_printer_driver.dart';
import '../../core/theme/app_theme.dart';
import '../../data/local/app_database.dart';
import '../../data/local/models.dart';
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
  final _settingsStorage = SettingsStorage();
  final _authStorage = AuthStorage();
  final _printerManager = PrinterManager();
  
  List<String> _availablePorts = [];
  List<String> _winPrinters = [];
  final List<int> _baudRates = [9600, 19200, 38400, 57600, 115200];

  PrinterConnectionType _receiptType = PrinterConnectionType.serial;
  String? _receiptPort;
  int _receiptBaudInt = 9600;

  List<KitchenStationModel> _kitchenStations = [];
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
    final ports = SerialPrinterService().getAvailablePorts();
    final winPrinters = WindowsPrinterDriver.listPrinters();
    
    final rType = await _settingsStorage.getReceiptPrinterType();
    final rPort = await _settingsStorage.getReceiptPrinterPort();
    final rBaud = await _settingsStorage.getReceiptPrinterBaud();

    final kType = await _settingsStorage.getKitchenPrinterType();
    final kPort = await _settingsStorage.getKitchenPrinterPort();
    final kBaud = await _settingsStorage.getKitchenPrinterBaud();

    final useSession = await _settingsStorage.getUsePosSession();
    
    // Load Kitchen Stations
    List<KitchenStationModel> stations = await widget.database.getKitchenStations();
    if (stations.isEmpty) {
      // Create default station if none exists (using legacy settings)
      final kType = await _settingsStorage.getKitchenPrinterType();
      final kPort = await _settingsStorage.getKitchenPrinterPort();
      final kBaud = await _settingsStorage.getKitchenPrinterBaud();
      
      final defaultStation = KitchenStationModel(
        id: 'default_kitchen',
        storeId: '', // Will be updated during sync
        name: '기본 주방',
        deviceType: kPort != null ? 'PRINTER' : 'NONE',
        deviceConfig: kPort != null ? json.encode({
          'type': kType.name,
          'connectionId': kPort,
          'baud': kBaud,
        }) : null,
        isDefault: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await widget.database.upsertKitchenStations([defaultStation]);
      stations = [defaultStation];
    }

    setState(() {
      _availablePorts = ports;
      _winPrinters = winPrinters;
      _receiptType = rType;
      _receiptPort = rPort;
      _receiptBaudInt = rBaud;
      _kitchenStations = stations;
      _usePosSession = useSession;
      _isLoading = false;
    });
    
    await _loadDataCounts();
  }

  Future<void> _saveSettings() async {
    await _settingsStorage.setUsePosSession(_usePosSession);

    await _settingsStorage.setReceiptPrinterType(_receiptType);
    if (_receiptPort != null) {
      await _settingsStorage.setReceiptPrinterPort(_receiptPort!);
      await _settingsStorage.setReceiptPrinterBaud(_receiptBaudInt);
    }
    
    // Save Kitchen Stations
    await widget.database.upsertKitchenStations(_kitchenStations);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다.')),
      );
    }
  }

  Future<void> _testPrint(String type, {KitchenStationModel? station}) async {
    final title = station != null ? station.name : (type == 'receipt' ? 'Receipt Printer' : 'Kitchen Printer');
    
    print('SettingsPage: Starting test print for $title');
    
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
      bool success = false;
      
      if (type == 'receipt') {
        success = await _printerManager.printReceipt(bytes);
      } else {
        success = await _printerManager.printKitchenOrder(bytes, station: station);
      }

      if (!success && mounted) {
        String msg = '$title 인쇄에 실패했습니다. 설정을 확인해 주세요.';
        if (station?.deviceType == 'NONE') msg = '해당 주방 스테이션의 장치 성격이 NONE으로 설정되어 있습니다.';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      print('SettingsPage: Test print error: $e');
    }
  }

  void _addKitchenStation() {
    final newStation = KitchenStationModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      storeId: '',
      name: '새 주방 ${_kitchenStations.length + 1}',
      deviceType: 'PRINTER',
      isDefault: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    setState(() {
      _kitchenStations.add(newStation);
    });
  }

  void _removeKitchenStation(String id) {
    if (_kitchenStations.any((s) => s.id == id && s.isDefault)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기본 주방은 삭제할 수 없습니다.')),
      );
      return;
    }
    setState(() {
      _kitchenStations.removeWhere((s) => s.id == id);
    });
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
                      type: _receiptType,
                      portValue: _receiptPort,
                      baudValue: _receiptBaudInt,
                      onTypeChanged: (val) => setState(() => _receiptType = val!),
                      onPortChanged: (val) => setState(() => _receiptPort = val),
                      onBaudChanged: (val) => setState(() => _receiptBaudInt = val ?? 9600),
                      onTestPrint: () => _testPrint('receipt'),
                    ),
                    const SizedBox(height: 24),
                    _buildSection(
                      title: AppLocalizations.of(context)!.translate('settings.kitchenPrinter') ?? '주방 스테이션 관리',
                      children: [
                        ..._kitchenStations.map((station) => _buildKitchenStationCard(station)).toList(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton.icon(
                            onPressed: _addKitchenStation,
                            icon: const Icon(Icons.add),
                            label: const Text('주방 스테이션 추가'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildKitchenStationCard(KitchenStationModel station) {
    Map<String, dynamic> config = {};
    if (station.deviceConfig != null) {
      try { config = json.decode(station.deviceConfig!); } catch (_) {}
    }

    final typeStr = config['type'] as String? ?? 'serial';
    final type = PrinterConnectionType.values.firstWhere((e) => e.name == typeStr, orElse: () => PrinterConnectionType.serial);
    final connectionId = config['connectionId'] as String?;
    final baud = config['baud'] as int? ?? 9600;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: station.isDefault ? BorderSide(color: AppTheme.primary.withOpacity(0.5), width: 1) : BorderSide.none,
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                station.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (station.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('기본', style: TextStyle(fontSize: 10, color: AppTheme.primary)),
              ),
          ],
        ),
        subtitle: Text(
          station.deviceType == 'NONE' ? '장치 없음' : '${type.name.toUpperCase()} - ${connectionId ?? "미설정"}',
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          onPressed: station.isDefault ? null : () => _removeKitchenStation(station.id),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  initialValue: station.name,
                  decoration: const InputDecoration(labelText: '주방 이름', border: OutlineInputBorder()),
                  onChanged: (val) {
                    setState(() {
                      final idx = _kitchenStations.indexWhere((s) => s.id == station.id);
                      if (idx != -1) {
                        _kitchenStations[idx] = KitchenStationModel(
                          id: station.id,
                          storeId: station.storeId,
                          name: val,
                          deviceType: station.deviceType,
                          deviceConfig: station.deviceConfig,
                          isDefault: station.isDefault,
                          createdAt: station.createdAt,
                          updatedAt: DateTime.now(),
                        );
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: station.deviceType,
                  decoration: const InputDecoration(labelText: '장치 유형', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'PRINTER', child: Text('영수증 프린터')),
                    DropdownMenuItem(value: 'KDS', child: Text('주방 모니터(KDS)')),
                    DropdownMenuItem(value: 'NONE', child: Text('출력 안함')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      final idx = _kitchenStations.indexWhere((s) => s.id == station.id);
                      if (idx != -1) {
                        _kitchenStations[idx] = KitchenStationModel(
                          id: station.id,
                          storeId: station.storeId,
                          name: station.name,
                          deviceType: val!,
                          deviceConfig: station.deviceConfig,
                          isDefault: station.isDefault,
                          createdAt: station.createdAt,
                          updatedAt: DateTime.now(),
                        );
                      }
                    });
                  },
                ),
                if (station.deviceType == 'PRINTER') ...[
                  const SizedBox(height: 16),
                  _buildPrinterSettingsInline(
                    type: type,
                    connectionId: connectionId,
                    baud: baud,
                    onConfigChanged: (newConfig) {
                      setState(() {
                        final idx = _kitchenStations.indexWhere((s) => s.id == station.id);
                        if (idx != -1) {
                          _kitchenStations[idx] = KitchenStationModel(
                            id: station.id,
                            storeId: station.storeId,
                            name: station.name,
                            deviceType: station.deviceType,
                            deviceConfig: json.encode(newConfig),
                            isDefault: station.isDefault,
                            createdAt: station.createdAt,
                            updatedAt: DateTime.now(),
                          );
                        }
                      });
                    },
                    onTestPrint: () => _testPrint('kitchen', station: station),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterSettingsInline({
    required PrinterConnectionType type,
    required String? connectionId,
    required int baud,
    required Function(Map<String, dynamic>) onConfigChanged,
    required VoidCallback onTestPrint,
  }) {
    return Column(
      children: [
        Row(
          children: [
            const Text('연결 방식: '),
            const SizedBox(width: 8),
            DropdownButton<PrinterConnectionType>(
              value: type,
              items: PrinterConnectionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
              onChanged: (val) {
                onConfigChanged({
                  'type': val!.name,
                  'connectionId': connectionId,
                  'baud': baud,
                });
              },
            ),
          ],
        ),
        if (type == PrinterConnectionType.serial) ...[
          ListTile(
            title: const Text('포트(COM)'),
            trailing: DropdownButton<String>(
              value: connectionId != null && _availablePorts.contains(connectionId) ? connectionId : null,
              items: _availablePorts.map((port) => DropdownMenuItem(value: port, child: Text(port))).toList(),
              onChanged: (val) => onConfigChanged({'type': 'serial', 'connectionId': val, 'baud': baud}),
              hint: const Text('선택'),
            ),
          ),
          ListTile(
            title: const Text('속도(Baud)'),
            trailing: DropdownButton<int>(
              value: baud,
              items: _baudRates.map((b) => DropdownMenuItem(value: b, child: Text(b.toString()))).toList(),
              onChanged: (val) => onConfigChanged({'type': 'serial', 'connectionId': connectionId, 'baud': val}),
            ),
          ),
        ] else if (type == PrinterConnectionType.network) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: connectionId,
            decoration: const InputDecoration(labelText: 'IP 주소 (예: 192.168.0.100:9100)', border: OutlineInputBorder()),
            onChanged: (val) => onConfigChanged({'type': 'network', 'connectionId': val, 'baud': baud}),
          ),
        ] else if (type == PrinterConnectionType.windows) ...[
          ListTile(
            title: const Text('프린터'),
            trailing: DropdownButton<String>(
              value: connectionId != null && _winPrinters.contains(connectionId) ? connectionId : null,
              items: _winPrinters.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
              onChanged: (val) => onConfigChanged({'type': 'windows', 'connectionId': val, 'baud': baud}),
              hint: const Text('선택'),
            ),
          ),
        ],
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onTestPrint,
          icon: const Icon(Icons.print, size: 18),
          label: const Text('주방 테스트 인쇄'),
        ),
      ],
    );
  }

  Widget _buildPrinterSection({
    required String title,
    required PrinterConnectionType type,
    required String? portValue,
    required int baudValue,
    required ValueChanged<PrinterConnectionType?> onTypeChanged,
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                DropdownButton<PrinterConnectionType>(
                  value: type,
                  items: PrinterConnectionType.values.map((t) => DropdownMenuItem(
                    value: t, 
                    child: Text(t.name.toUpperCase())
                  )).toList(),
                  onChanged: onTypeChanged,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (type == PrinterConnectionType.serial) ...[
            ListTile(
              title: Text(AppLocalizations.of(context)!.translate('settings.serialPort') ?? '포트(COM)'),
              trailing: DropdownButton<String>(
                value: portValue != null && _availablePorts.contains(portValue) ? portValue : null,
                items: _availablePorts.map((port) => DropdownMenuItem(value: port, child: Text(port))).toList(),
                onChanged: onPortChanged,
                hint: Text(AppLocalizations.of(context)!.translate('common.select') ?? '선택'),
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.translate('settings.baudRate') ?? '속도(Baud)'),
              trailing: DropdownButton<int>(
                value: baudValue,
                items: _baudRates.map((baud) => DropdownMenuItem(value: baud, child: Text(baud.toString()))).toList(),
                onChanged: onBaudChanged,
              ),
            ),
          ] else if (type == PrinterConnectionType.network) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                initialValue: portValue,
                decoration: InputDecoration(
                  labelText: 'IP Address (e.g. 192.168.0.100:9100)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: onPortChanged,
              ),
            ),
          ] else if (type == PrinterConnectionType.windows) ...[
            ListTile(
              title: const Text('Windows Printer'),
              trailing: DropdownButton<String>(
                value: portValue != null && _winPrinters.contains(portValue) ? portValue : null,
                items: _winPrinters.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                onChanged: onPortChanged,
                hint: const Text('프린터 선택'),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: onTestPrint,
              child: Text(AppLocalizations.of(context)!.translate('settings.testPrint') ?? '테스트 인쇄'),
            ),
          ),
        ],
      ),
    );
  }
}

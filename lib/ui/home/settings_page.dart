import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/i18n/app_localizations.dart';
import '../../core/printer/serial_printer_service.dart';
import '../../core/printer/esc_pos_encoder.dart';
import '../../core/printer/receipt_templates.dart';
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
      // 샘플 데이터 생성
      final sampleSale = _createSampleSale();
      final sampleItems = _createSampleItems();
      final sampleProducts = _createSampleProducts();
      
      // 백오피스 설정 가져오기
      final sessionInfo = await _authStorage.getSessionInfo();
      final storeInfo = {
        'storeName': sessionInfo['storeName'] ?? '포스에이스 테스트 매장',
        'storeAddress': sessionInfo['storeAddress'] ?? '서울특별시 강남구 테헤란로 123',
        'storePhone': sessionInfo['storePhone'] ?? '02-1234-5678',
        'businessNumber': sessionInfo['businessNumber'] ?? '123-45-67890',
      };
      
      // 매장 설정 가져오기 (없으면 null)
      StoreSettingsModel? storeSettings;
      try {
        // TODO: 로컬 DB에서 매장 설정 가져오기
        // final storeSettings = await widget.database.getStoreSettings();
      } catch (e) {
        print('Store settings not available: $e');
      }
      
      // 영수증 또는 주방주문서 생성
      final bytes = type == 'receipt'
        ? await ReceiptTemplates.saleReceipt(
            sampleSale,
            sampleItems,
            sampleProducts,
            storeInfo: storeInfo,
            settings: storeSettings,
            context: context,
          )
        : await ReceiptTemplates.kitchenOrder(
            sampleSale,
            sampleItems,
            sampleProducts,
            itemOptions: _createSampleOptions(sampleItems),
            context: context,
          );
      
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
      } else if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title 테스트 인쇄 완료')),
        );
      }
    } catch (e) {
      print('SettingsPage: Test print error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('테스트 인쇄 중 오류 발생: $e')),
        );
      }
    }
  }
  
  SaleModel _createSampleSale() {
    return SaleModel(
      id: 'test-${DateTime.now().millisecondsSinceEpoch}',
      storeId: 'test-store',
      posId: 'test-pos',
      sessionId: 'test-session',
      employeeId: 'test-employee',
      totalAmount: 23100,
      paidAmount: 23100,
      paymentMethod: 'CASH',
      status: 'COMPLETED',
      createdAt: DateTime.now(),
      taxAmount: 2100,
      discountAmount: 2000,
    );
  }
  
  List<SaleItemModel> _createSampleItems() {
    return [
      SaleItemModel(
        id: 'item-1',
        saleId: 'test-sale',
        productId: 'prod-1',
        qty: 2,
        price: 4500,
        discountAmount: 0,
      ),
      SaleItemModel(
        id: 'item-2',
        saleId: 'test-sale',
        productId: 'prod-2',
        qty: 1,
        price: 5000,
        discountAmount: 0,
      ),
      SaleItemModel(
        id: 'item-3',
        saleId: 'test-sale',
        productId: 'prod-3',
        qty: 1,
        price: 7000,
        discountAmount: 2000,
      ),
    ];
  }
  
  Map<String, ProductModel> _createSampleProducts() {
    return {
      'prod-1': ProductModel(
        id: 'prod-1',
        storeId: 'test-store',
        categoryId: 'cat-1',
        name: '아메리카노',
        type: 'SINGLE',
        price: 4500,
        stockEnabled: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      'prod-2': ProductModel(
        id: 'prod-2',
        storeId: 'test-store',
        categoryId: 'cat-1',
        name: '카페라떼',
        type: 'SINGLE',
        price: 5000,
        stockEnabled: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      'prod-3': ProductModel(
        id: 'prod-3',
        storeId: 'test-store',
        categoryId: 'cat-2',
        name: '치즈케이크',
        type: 'SINGLE',
        price: 7000,
        stockEnabled: false,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    };
  }
  
  Map<String, List<ProductOptionModel>> _createSampleOptions(List<SaleItemModel> items) {
    // 샘플 옵션: 아메리카노에 휘핑크림과 샷 추가
    return {
      items[0].id: [
        ProductOptionModel(
          id: 'opt-1',
          groupId: 'group-1',
          name: '휘핑크림 추가',
          priceAdjustment: 500,
          sortOrder: 1,
        ),
        ProductOptionModel(
          id: 'opt-2',
          groupId: 'group-2',
          name: '샷 추가',
          priceAdjustment: 500,
          sortOrder: 2,
        ),
      ],
      // 카페라떼에 시럽 추가
      items[1].id: [
        ProductOptionModel(
          id: 'opt-3',
          groupId: 'group-3',
          name: '바닐라 시럽',
          priceAdjustment: 500,
          sortOrder: 1,
        ),
      ],
    };
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
                        // 주방이 1개일 때는 항상 펼쳐진 Card, 여러 개일 때는 ExpansionTile
                        ..._kitchenStations.map((station) {
                          final isSingleKitchen = _kitchenStations.length == 1;
                          return isSingleKitchen 
                            ? _buildExpandedKitchenCard(station)
                            : _buildKitchenStationCard(station);
                        }).toList(),
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

  Widget _buildExpandedKitchenCard(KitchenStationModel station) {
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
        side: station.isDefault ? BorderSide(color: AppTheme.primary.withOpacity(0.5), width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    station.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (station.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('기본', style: TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              station.deviceType == 'NONE' 
                ? '장치 없음' 
                : '${type == PrinterConnectionType.windows ? "WINDOWS PRINTER" : type.name.toUpperCase()} - ${connectionId ?? "미설정"}',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const Divider(height: 32),
            // Content
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
                DropdownMenuItem(
                  value: 'KDS',
                  enabled: false,
                  child: Text(
                    '주방 모니터(KDS) - 준비 중',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
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
          station.deviceType == 'NONE' 
            ? '장치 없음' 
            : '${type == PrinterConnectionType.windows ? "WINDOWS PRINTER" : type.name.toUpperCase()} - ${connectionId ?? "미설정"}',
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
                    DropdownMenuItem(
                      value: 'KDS',
                      enabled: false,
                      child: Text(
                        '주방 모니터(KDS) - 준비 중',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
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
              items: PrinterConnectionType.values.map((t) => DropdownMenuItem(
                value: t, 
                child: Text(t == PrinterConnectionType.windows ? 'WINDOWS PRINTER' : t.name.toUpperCase())
              )).toList(),
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
                    child: Text(t == PrinterConnectionType.windows ? 'WINDOWS PRINTER' : t.name.toUpperCase())
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

import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../core/printer/serial_printer_service.dart';
import '../../core/printer/esc_pos_encoder.dart';
import '../../core/storage/settings_storage.dart';
import '../../core/theme/app_theme.dart';
import '../sales/widgets/title_bar.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _printerService = SerialPrinterService();
  final _settingsStorage = SettingsStorage();
  
  List<String> _availablePorts = [];
  final List<int> _baudRates = [9600, 19200, 38400, 57600, 115200];

  String? _receiptPort;
  int _receiptBaudInt = 9600; // Renamed from _receiptBaud
  String? _kitchenPort;
  int _kitchenBaud = 9600;
  bool _usePosSession = true; // New state variable

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          TitleBar(
            title: '환경설정',
            onHomePressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    _buildSection(
                      title: '일반 설정',
                      children: [
                        SwitchListTile(
                          title: const Text('영업 시작/마감 기능 사용'),
                          subtitle: const Text('비활성화 시 세션 오픈 없이 바로 판매가 가능합니다.'),
                          value: _usePosSession,
                          onChanged: (val) => setState(() => _usePosSession = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildPrinterSection(
                      title: '영수증 프린터 설정',
                      portValue: _receiptPort,
                      baudValue: _receiptBaudInt, // Fix variable name
                      onPortChanged: (val) => setState(() => _receiptPort = val),
                      onBaudChanged: (val) => setState(() => _receiptBaudInt = val ?? 9600),
                      onTestPrint: () => _testPrint('receipt'),
                    ),
                    const SizedBox(height: 24),
                    _buildPrinterSection(
                      title: '주방 프린터 설정',
                      portValue: _kitchenPort,
                      baudValue: _kitchenBaud,
                      onPortChanged: (val) => setState(() => _kitchenPort = val),
                      onBaudChanged: (val) => setState(() => _kitchenBaud = val ?? 9600),
                      onTestPrint: () => _testPrint('kitchen'),
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
            title: const Text('시리얼 포트 (COM)'),
            trailing: DropdownButton<String>(
              value: portValue,
              items: _availablePorts.map((port) => DropdownMenuItem(value: port, child: Text(port))).toList(),
              onChanged: onPortChanged,
              hint: const Text('포트 선택'),
            ),
          ),
          ListTile(
            title: const Text('통신 속도 (Baud Rate)'),
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
              child: const Text('테스트 인쇄'),
            ),
          ),
        ],
      ),
    );
  }
}

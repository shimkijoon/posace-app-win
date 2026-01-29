import 'dart:typed_data';
import 'serial_printer_service.dart';
import 'printer_driver.dart';

class SerialPrinterDriver implements PrinterDriver {
  final String portName;
  final int baudRate;
  final SerialPrinterService _service = SerialPrinterService();

  SerialPrinterDriver({required this.portName, this.baudRate = 9600});

  @override
  String get connectionId => portName;

  @override
  Map<String, dynamic> get params => {'portName': portName, 'baudRate': baudRate};

  @override
  bool get isConnected => _service.isConnected(portName);

  @override
  Future<bool> connect() async {
    return _service.connect(portName, baudRate: baudRate);
  }

  @override
  Future<void> disconnect() async {
    _service.disconnect(portName);
  }

  @override
  Future<bool> printBytes(Uint8List bytes) async {
    // 연결되지 않은 경우 자동 연결 시도
    if (!isConnected) {
      print('SerialPrinterDriver: Not connected to $portName, attempting to connect...');
      final connected = await connect();
      if (!connected) {
        print('SerialPrinterDriver: Failed to connect to $portName');
        return false;
      }
    }
    return _service.printBytes(portName, bytes);
  }
}

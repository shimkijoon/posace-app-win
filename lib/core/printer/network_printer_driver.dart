import 'dart:io';
import 'dart:typed_data';
import 'printer_driver.dart';

class NetworkPrinterDriver implements PrinterDriver {
  final String ip;
  final int port;
  Socket? _socket;
  bool _isConnected = false;

  NetworkPrinterDriver({required this.ip, this.port = 9100});

  @override
  String get connectionId => '$ip:$port';

  @override
  Map<String, dynamic> get params => {'ip': ip, 'port': port};

  @override
  bool get isConnected => _isConnected && _socket != null;

  @override
  Future<bool> connect() async {
    try {
      print('NetworkPrinterDriver: Connecting to $ip:$port...');
      _socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
      _isConnected = true;
      print('NetworkPrinterDriver: Connected successfully.');
      
      // Listen for socket closure
      _socket!.done.then((_) {
        print('NetworkPrinterDriver: Socket closed.');
        _isConnected = false;
        _socket = null;
      });
      
      return true;
    } catch (e) {
      print('NetworkPrinterDriver: Connection failed: $e');
      _isConnected = false;
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    print('NetworkPrinterDriver: Disconnecting...');
    await _socket?.close();
    _socket = null;
    _isConnected = false;
  }

  @override
  Future<bool> printBytes(Uint8List bytes) async {
    if (!isConnected) {
      print('NetworkPrinterDriver: Not connected. Attempting auto-connect...');
      if (!await connect()) return false;
    }

    try {
      print('NetworkPrinterDriver: Sending ${bytes.length} bytes...');
      _socket!.add(bytes);
      await _socket!.flush();
      print('NetworkPrinterDriver: Bytes sent successfully.');
      return true;
    } catch (e) {
      print('NetworkPrinterDriver: Print failed: $e');
      return false;
    }
  }
}

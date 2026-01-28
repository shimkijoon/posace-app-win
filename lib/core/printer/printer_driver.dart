import 'dart:typed_data';

abstract class PrinterDriver {
  /// Unique identifier for this printer configuration (e.g. "COM1", "192.168.0.100", "Windows-Printer-Name")
  String get connectionId;

  /// Connection parameters specific to the driver type
  Map<String, dynamic> get params;

  /// Returns true if the hardware is currently connected or accessible
  bool get isConnected;

  /// Connect to the printer hardware
  Future<bool> connect();

  /// Gracefully close the connection
  Future<void> disconnect();

  /// Send raw bytes (ESC/POS) to the printer
  Future<bool> printBytes(Uint8List bytes);
}

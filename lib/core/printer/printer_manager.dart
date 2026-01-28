import 'dart:typed_data';
import '../storage/settings_storage.dart';
import 'printer_driver.dart';
import 'serial_printer_driver.dart';
import 'network_printer_driver.dart';
import 'windows_printer_driver.dart';

class PrinterManager {
  static final PrinterManager _instance = PrinterManager._internal();
  factory PrinterManager() => _instance;
  PrinterManager._internal();

  final Map<String, PrinterDriver> _drivers = {};

  Future<PrinterDriver?> _getReceiptDriver() async {
    final settings = SettingsStorage();
    final type = await settings.getReceiptPrinterType();
    final id = await settings.getReceiptPrinterPort(); // We use 'port' field for IP/Name too
    final baud = await settings.getReceiptPrinterBaud();

    if (id == null || id.isEmpty) return null;
    
    final key = 'receipt_${type.name}_$id';
    if (_drivers.containsKey(key)) return _drivers[key];

    PrinterDriver driver;
    switch (type) {
      case PrinterConnectionType.network:
        final parts = id.split(':');
        final ip = parts[0];
        final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        driver = NetworkPrinterDriver(ip: ip, port: port);
        break;
      case PrinterConnectionType.windows:
        driver = WindowsPrinterDriver(printerName: id);
        break;
      case PrinterConnectionType.serial:
      default:
        driver = SerialPrinterDriver(portName: id, baudRate: baud);
        break;
    }

    _drivers[key] = driver;
    return driver;
  }

  Future<PrinterDriver?> _getKitchenDriver() async {
    final settings = SettingsStorage();
    final type = await settings.getKitchenPrinterType();
    final id = await settings.getKitchenPrinterPort();
    final baud = await settings.getKitchenPrinterBaud();

    if (id == null || id.isEmpty) return null;

    final key = 'kitchen_${type.name}_$id';
    if (_drivers.containsKey(key)) return _drivers[key];

    PrinterDriver driver;
    switch (type) {
      case PrinterConnectionType.network:
        final parts = id.split(':');
        final ip = parts[0];
        final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        driver = NetworkPrinterDriver(ip: ip, port: port);
        break;
      case PrinterConnectionType.windows:
        driver = WindowsPrinterDriver(printerName: id);
        break;
      case PrinterConnectionType.serial:
      default:
        driver = SerialPrinterDriver(portName: id, baudRate: baud);
        break;
    }

    _drivers[key] = driver;
    return driver;
  }

  Future<bool> printReceipt(Uint8List bytes) async {
    final driver = await _getReceiptDriver();
    if (driver == null) {
      print('PrinterManager: No receipt printer configured.');
      return false;
    }
    return driver.printBytes(bytes);
  }

  Future<bool> printKitchenOrder(Uint8List bytes) async {
    final driver = await _getKitchenDriver();
    if (driver == null) {
      print('PrinterManager: No kitchen printer configured.');
      return false;
    }
    return driver.printBytes(bytes);
  }
}

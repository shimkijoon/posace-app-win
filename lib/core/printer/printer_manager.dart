import 'dart:convert';
import 'dart:typed_data';
import '../storage/settings_storage.dart';
import '../../data/local/models.dart';
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
    final id = await settings.getReceiptPrinterPort();
    final baud = await settings.getReceiptPrinterBaud();

    if (id == null || id.isEmpty) return null;
    
    return _getDriverFromConfig(type, id, baud, 'receipt');
  }

  Future<PrinterDriver?> _getDriverFromConfig(
    PrinterConnectionType type, 
    String connectionId, 
    int baud, 
    String prefix
  ) async {
    final key = '${prefix}_${type.name}_$connectionId';
    if (_drivers.containsKey(key)) return _drivers[key];

    PrinterDriver driver;
    switch (type) {
      case PrinterConnectionType.network:
        final parts = connectionId.split(':');
        final ip = parts[0];
        final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;
        driver = NetworkPrinterDriver(ip: ip, port: port);
        break;
      case PrinterConnectionType.windows:
        driver = WindowsPrinterDriver(printerName: connectionId);
        break;
      case PrinterConnectionType.serial:
      default:
        driver = SerialPrinterDriver(portName: connectionId, baudRate: baud);
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

  Future<bool> printKitchenOrder(Uint8List bytes, {KitchenStationModel? station}) async {
    PrinterDriver? driver;

    if (station != null) {
      if (station.deviceType == 'PRINTER' && station.deviceConfig != null) {
        try {
          final config = json.decode(station.deviceConfig!);
          final typeStr = config['type'] as String? ?? 'serial';
          final connectionId = config['connectionId'] as String?;
          final baud = config['baud'] as int? ?? 9600;

          if (connectionId != null && connectionId.isNotEmpty) {
            final type = PrinterConnectionType.values.firstWhere(
              (e) => e.name == typeStr,
              orElse: () => PrinterConnectionType.serial,
            );
            driver = await _getDriverFromConfig(type, connectionId, baud, 'station_${station.id}');
          }
        } catch (e) {
          print('PrinterManager: Error parsing station config for ${station.name}: $e');
        }
      } else if (station.deviceType == 'NONE') {
        print('PrinterManager: Station ${station.name} is set to NONE. Skipping.');
        return true;
      }
    } else {
      // Fallback to legacy kitchen printer setting
      driver = await _getKitchenDriver();
    }

    if (driver == null) {
      print('PrinterManager: No printer driver resolved for kitchen order.');
      return false;
    }
    return driver.printBytes(bytes);
  }
}

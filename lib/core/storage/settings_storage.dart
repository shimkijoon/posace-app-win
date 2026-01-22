import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorage {
  static const _keyReceiptPrinterPort = 'receipt_printer_port';
  static const _keyReceiptPrinterBaud = 'receipt_printer_baud';
  static const _keyKitchenPrinterPort = 'kitchen_printer_port';
  static const _keyKitchenPrinterBaud = 'kitchen_printer_baud';

  static final SettingsStorage _instance = SettingsStorage._internal();
  factory SettingsStorage() => _instance;
  SettingsStorage._internal();

  // Receipt Printer
  Future<void> setReceiptPrinterPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyReceiptPrinterPort, port);
  }

  Future<String?> getReceiptPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyReceiptPrinterPort);
  }

  Future<void> setReceiptPrinterBaud(int baud) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReceiptPrinterBaud, baud);
  }

  Future<int> getReceiptPrinterBaud() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyReceiptPrinterBaud) ?? 9600;
  }

  // Kitchen Printer
  Future<void> setKitchenPrinterPort(String port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyKitchenPrinterPort, port);
  }

  Future<String?> getKitchenPrinterPort() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyKitchenPrinterPort);
  }

  Future<void> setKitchenPrinterBaud(int baud) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyKitchenPrinterBaud, baud);
  }

  Future<int> getKitchenPrinterBaud() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyKitchenPrinterBaud) ?? 9600;
  }
}

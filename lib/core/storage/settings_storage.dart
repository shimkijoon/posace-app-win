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

  // Session Management
  static const _keyUsePosSession = 'use_pos_session';

  Future<void> setUsePosSession(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUsePosSession, value);
  }

  Future<bool> getUsePosSession() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true as it was the original behavior
    return prefs.getBool(_keyUsePosSession) ?? true;
  }

  // Sync Management
  static const _keyLastSyncAt = 'last_sync_at';
  static const _keyScheduledSyncTimes = 'scheduled_sync_times';

  Future<void> setLastSyncAt(DateTime value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastSyncAt, value.toIso8601String());
  }

  Future<DateTime?> getLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyLastSyncAt);
    return value != null ? DateTime.parse(value) : null;
  }

  Future<void> setScheduledSyncTimes(List<String> times) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyScheduledSyncTimes, times);
  }

  Future<List<String>> getScheduledSyncTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyScheduledSyncTimes) ?? ['08:00', '14:00', '22:00'];
  }
}

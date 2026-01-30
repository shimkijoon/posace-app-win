import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'app_config.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse('${AppConfig.apiBaseUrl}/app/version'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['version'] as String;
        final info = await PackageInfo.fromPlatform();
        final currentVersion = info.version;
        
        if (_isNewer(latestVersion, currentVersion)) {
          return data;
        }
      }
    } catch (e) {
      print('[VersionService] Error checking update: $e');
    }
    return null;
  }

  bool _isNewer(String latest, String current) {
    List<int> latestParts = latest.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    List<int> currentParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    
    for (var i = 0; i < latestParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    return false;
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'app_config.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  // Point to the Next.js API in backoffice
  // Dev: localhost:3002 (posace-backoffice)
  // Prod: backoffice.posace.com
  static String get _updateUrl {
    if (kReleaseMode) {
      return '${AppConfig.backofficeBaseUrl}/api/download/windows?mode=json';
    } else {
      return '${AppConfig.backofficeBaseUrl}/api/download/windows?mode=json';
    }
  }

  Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['version'] as String; // e.g. "v1.0.1-win"
        
        final info = await PackageInfo.fromPlatform();
        final currentVersion = info.version;
        
        // Clean the tag to get pure version number
        final cleanLatestVersion = _cleanVersion(latestTag);
        
        if (_isNewer(cleanLatestVersion, currentVersion)) {
          return {
            'version': latestTag,
            'url': data['url'],
            'changelog': data['notes'],
            'mandatory': false, // Optional by default
          };
        }
      }
    } catch (e) {
      print('[VersionService] Error checking update: $e');
    }
    return null;
  }

  String _cleanVersion(String tag) {
    // Remove "v", "V" from start
    String v = tag.replaceAll(RegExp(r'^[vV]'), '');
    // Remove suffixes like "-win", "+build"
    v = v.split('-')[0].split('+')[0];
    return v;
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

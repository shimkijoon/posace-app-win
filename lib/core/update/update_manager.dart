import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateManager {
  // TODO: Replace with your actual production domain
  static const String _updateUrl = 'https://www.posace.com/api/download/windows?mode=json';

  Future<void> checkAndPromptUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "1.0.0"

      debugPrint('Checking for updates... Current: $currentVersion');

      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final remoteTag = data['version'] as String; // e.g. "v1.0.1-win"
        final remoteUrl = data['url'] as String;
        final notes = data['notes'] as String?;

        final cleanRemoteVersion = _cleanVersion(remoteTag);
        
        if (_isNewer(cleanRemoteVersion, currentVersion)) {
           if (context.mounted) {
             _showUpdateDialog(context, remoteTag, remoteUrl, notes);
           }
        } else {
          debugPrint('App is up to date.');
        }
      } else {
        debugPrint('Update check failed status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  String _cleanVersion(String tag) {
    // Remove 'v', '-win', etc. Keep "1.0.1"
    String v = tag.replaceAll(RegExp(r'[vV]'), '');
    v = v.split('-')[0]; // Remove suffixes like -win
    return v;
  }

  bool _isNewer(String remote, String local) {
    try {
      List<int> rParts = remote.split('.').map(int.parse).toList();
      List<int> lParts = local.split('.').map(int.parse).toList();

      for (int i = 0; i < rParts.length; i++) {
        if (i >= lParts.length) return true; // Remote has more parts (e.g. 1.0.1 vs 1.0)
        if (rParts[i] > lParts[i]) return true;
        if (rParts[i] < lParts[i]) return false;
      }
      return false; // Equal
    } catch (e) {
      return false; // Parse error
    }
  }

  void _showUpdateDialog(BuildContext context, String version, String url, String? notes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New Version Available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version ($version) is available.'),
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text('Release Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(notes, style: const TextStyle(fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 20),
            const Text('Would you like to download it now?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}

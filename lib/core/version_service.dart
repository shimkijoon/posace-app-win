import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'app_config.dart';
import 'i18n/app_localizations.dart';
import 'theme/app_theme.dart';

class VersionService {
  static final VersionService _instance = VersionService._internal();
  factory VersionService() => _instance;
  VersionService._internal();

  static bool _isDialogShowing = false;

  // Point to the Next.js API in backoffice
  // Dev: localhost:3002 (posace-backoffice)
  // Prod: backoffice.posace.com
  static String get _updateUrl {
    return '${AppConfig.backofficeBaseUrl}/api/download/windows?mode=json';
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
      debugPrint('[VersionService] Error checking update: $e');
    }
    return null;
  }

  /// Checks for updates and shows a concise dialog if available.
  Future<void> showUpdateDialogIfAvailable(BuildContext context) async {
    if (_isDialogShowing) return;

    final updateInfo = await checkUpdate();
    if (updateInfo == null) return;

    if (!context.mounted) return;

    _isDialogShowing = true;
    
    final localizations = AppLocalizations.of(context);
    final String title = localizations?.translate('home.updateTitle') ?? '새로운 버전 업데이트';
    final String message = localizations?.translate('home.updateMessage') ?? '최신 버전이 출시되었습니다. 업데이트하시겠습니까?';
    final String updateNow = localizations?.translate('common.updateNow') ?? '지금 업데이트';
    final String later = localizations?.translate('common.later') ?? '나중에';

    await showDialog(
      context: context,
      barrierDismissible: !(updateInfo['mandatory'] ?? false),
      builder: (context) => AlertDialog(
        title: Text('$title (${updateInfo['version']})'),
        content: Text(message),
        actions: [
          if (!(updateInfo['mandatory'] ?? false))
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(later),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _downloadAndInstall(context, updateInfo['url']);
            },
            child: Text(updateNow),
          ),
        ],
      ),
    );
    
    _isDialogShowing = false;
  }

  /// Shows a manual update dialog with current and latest version info.
  /// Allows forced update regardless of version comparison.
  Future<void> showManualUpdateDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final response = await http.get(Uri.parse(_updateUrl));
      if (context.mounted) Navigator.pop(context); // Close loading

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['version'] as String;
        final url = data['url'] as String;
        
        final info = await PackageInfo.fromPlatform();
        final currentVersion = info.version;

        if (!context.mounted) return;

        showDialog(
          context: context,
          builder: (context) {
            final bool isNewer = _isNewer(_cleanVersion(latestTag), currentVersion);
            
            return AlertDialog(
              title: Text(localizations?.translate('settings.versionInfo') ?? '버전 정보'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVersionRow(localizations?.translate('settings.currentVersion') ?? '현재 버전', currentVersion),
                  _buildVersionRow(
                    localizations?.translate('settings.latestVersion') ?? '최신 버전', 
                    latestTag,
                    onTap: () {
                      if (HardwareKeyboard.instance.isControlPressed) {
                        Navigator.pop(context);
                        _downloadAndInstall(context, url);
                      }
                    },
                    isVersionText: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations?.translate('settings.forceUpdateDesc') ?? '최신 버전으로 업데이트를 시작하려면 아래 버튼을 클릭하세요.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(localizations?.translate('common.close') ?? '닫기'),
                ),
                ElevatedButton(
                  onPressed: isNewer ? () {
                    Navigator.pop(context);
                    _downloadAndInstall(context, url);
                  } : null,
                  child: Text(localizations?.translate('common.updateNow') ?? '지금 업데이트'),
                ),
              ],
            );
          },
        );
      } else {
        throw Exception('Failed to fetch version info: ${response.statusCode}');
      }
    } catch (e) {
      if (context.mounted) {
        if (Navigator.canPop(context)) {
          // Navigator.pop(context); // This might close the wrong thing if not careful
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('버전 확인 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildVersionRow(String label, String value, {VoidCallback? onTap, bool isVersionText = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  value,
                  style: TextStyle(
                    color: isVersionText ? Colors.blue : null,
                    decoration: isVersionText ? TextDecoration.underline : null,
                  ),
                ),
              ),
            )
          else
            Text(value),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(BuildContext context, String url) async {
    final ValueNotifier<double> progressNotifier = ValueNotifier(0);
    final localizations = AppLocalizations.of(context);
    
    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<double>(
        valueListenable: progressNotifier,
        builder: (context, progress, child) => AlertDialog(
          title: Text(localizations?.translate('home.updateTitle') ?? '업데이트 다운로드 중...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 16),
              Text('${(progress * 100).toStringAsFixed(1)}%'),
            ],
          ),
        ),
      ),
    );

    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      
      final contentLength = response.contentLength ?? 0;
      int receivedLength = 0;
      
      final tempDir = await getTemporaryDirectory();
      // Use a consistent filename or one from URL if possible
      final fileName = url.split('/').last.split('?').first;
      final file = File('${tempDir.path}/$fileName');
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        receivedLength += chunk.length;
        sink.add(chunk);
        if (contentLength > 0) {
          progressNotifier.value = receivedLength / contentLength;
        }
      }

      debugPrint('[VersionService] Download complete. Finalizing file...');
      await sink.flush();
      await sink.close();
      client.close();
      debugPrint('[VersionService] File finalized. Path: ${file.path}');
      
      if (context.mounted) {
        Navigator.pop(context); // Close progress dialog
      }

      // Execute the installer and exit
      await _executeInstaller(file.path);
      
    } catch (e) {
      debugPrint('[VersionService] Error during download: $e');
      if (context.mounted) {
        // Ensure progress dialog is closed if it was shown
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('다운로드 오류: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _executeInstaller(String filePath) async {
    debugPrint('[VersionService] Executing installer: $filePath');
    
    // Detached process to allow app to exit while installer runs
    try {
      if (filePath.toLowerCase().endsWith('.exe')) {
        final process = await Process.start(filePath, [], mode: ProcessStartMode.detached);
        debugPrint('[VersionService] Installer process started. PID: ${process.pid}');
      } else if (filePath.toLowerCase().endsWith('.msix')) {
        // MSIX might need powershell or just direct start if it's associated
        final process = await Process.start('powershell', ['-Command', 'Start-Process', '"$filePath"'], mode: ProcessStartMode.detached);
        debugPrint('[VersionService] MSIX installer process started via powershell. PID: ${process.pid}');
      } else {
        // Try direct execution anyway
        final process = await Process.start(filePath, [], mode: ProcessStartMode.detached);
        debugPrint('[VersionService] Installer (unknown type) process started. PID: ${process.pid}');
      }
      
      // Wait a moment before exit to ensure process started
      await Future.delayed(const Duration(milliseconds: 500));
      debugPrint('[VersionService] Exiting app to allow installation...');
      exit(0);
    } catch (e) {
      debugPrint('[VersionService] Error executing installer: $e');
    }
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

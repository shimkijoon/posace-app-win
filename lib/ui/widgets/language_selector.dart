import 'package:flutter/material.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/utils/restart_widget.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.language),
      tooltip: '언어 선택',
      onSelected: (languageCode) async {
        // 앱 언어 저장
        await AuthStorage().saveAppLanguage(languageCode);
        // 앱 재시작하여 언어 적용
        if (context.mounted) {
          RestartWidget.restartApp(context);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'ko',
          child: Row(
            children: [
              Text('🇰🇷', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('한국어'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'ja',
          child: Row(
            children: [
              Text('🇯🇵', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('日本語'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'zh',
          child: Row(
            children: [
              Text('🇨🇳', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('中文'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'en',
          child: Row(
            children: [
              Text('🇺🇸', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text('English'),
            ],
          ),
        ),
      ],
    );
  }
}

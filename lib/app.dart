import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/theme/app_theme.dart';
import 'ui/home/home_page.dart';

class PosaceApp extends StatelessWidget {
  const PosaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}

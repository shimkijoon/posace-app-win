import 'package:flutter/material.dart';
import 'core/app_config.dart';
import 'core/storage/auth_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/local/app_database.dart';
import 'ui/auth/login_page.dart';
import 'ui/home/home_page.dart';

class PosaceApp extends StatelessWidget {
  const PosaceApp({super.key, required this.database});

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      home: FutureBuilder<String?>(
        future: AuthStorage().getAccessToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final token = snapshot.data;
          if (token == null || token.isEmpty) {
            return LoginPage(database: database);
          }
          return HomePage(database: database);
        },
      ),
    );
  }
}

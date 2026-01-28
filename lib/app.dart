import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_config.dart';
import 'core/storage/auth_storage.dart';
import 'core/theme/app_theme.dart';
import 'core/i18n/app_localizations.dart';
import 'core/i18n/locale_helper.dart';
import 'data/local/app_database.dart';
import 'ui/auth/login_page.dart';
import 'ui/home/home_page.dart';
import 'core/auth/pos_auth_service.dart';

class PosaceApp extends StatefulWidget {
  const PosaceApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<PosaceApp> createState() => _PosaceAppState();
}

class _PosaceAppState extends State<PosaceApp> {
  Locale? _locale;
  bool _isLoadingLocale = true;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final locale = await LocaleHelper.getLocale();
    print('[PosaceApp] Loaded locale: ${locale.languageCode}${locale.countryCode != null ? '-${locale.countryCode}' : ''}');
    if (mounted) {
      setState(() {
        _locale = locale;
        _isLoadingLocale = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLocale) {
      return MaterialApp(
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      title: AppConfig.appName,
      theme: AppTheme.light(),
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LocaleHelper.supportedLocales,
      home: FutureBuilder<bool>(
        future: _checkAuth(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final isAuthenticated = snapshot.data ?? false;
          if (!isAuthenticated) {
            return LoginPage(database: widget.database);
          }
          return HomePage(database: widget.database);
        },
      ),
    );
  }

  Future<bool> _checkAuth() async {
    return PosAuthService().verifyToken();
  }
}

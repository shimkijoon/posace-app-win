import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';
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

class _PosaceAppState extends State<PosaceApp> with WindowListener {
  Locale? _locale;
  bool _isLoadingLocale = true;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _initWindowManager();
    _loadLocale();
  }

  Future<void> _initWindowManager() async {
    // 창 닫기를 가로채기 위해 preventClose 설정
    await windowManager.setPreventClose(true);
    print('[PosaceApp] Window close prevention enabled');
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // 창 닫기를 시도할 때 호출됨
    final shouldClose = await _showExitConfirmDialog();
    if (shouldClose) {
      // 리소스 정리 및 종료
      await _cleanupAndExit();
    }
  }

  Future<void> _cleanupAndExit() async {
    print('[PosaceApp] Starting cleanup and exit...');
    
    // Fallback: 2초 내에 정상 종료되지 않으면 강제 종료 처리
    Future.delayed(const Duration(seconds: 2)).then((_) {
      print('[PosaceApp] Exit timeout reached. Forcing exit via dart:io...');
      exit(0);
    });

    try {
      // 비동기 작업 정리 (예: 프린터 종료 대기 등)
      // 필요한 핵심 리소스 정리를 여기에 추가
      
      // UI 스레드가 이벤트를 처리할 시간을 줌
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('[PosaceApp] Destroying window...');
      await windowManager.destroy();
    } catch (e) {
      print('[PosaceApp] Error during cleanup: $e');
      // 오류 발생 시에도 시스템 강제 종료
      exit(0);
    }
  }

  Future<bool> _showExitConfirmDialog() async {
    // BuildContext를 얻기 위해 GlobalKey 사용
    final context = navigatorKey.currentContext;
    if (context == null) return true;

    final localizations = AppLocalizations.of(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(localizations?.translate('app.exitConfirmTitle') ?? '종료 확인'),
        content: Text(
          localizations?.translate('app.exitConfirmMessage') ?? 
          '포스 프로그램을 종료하시겠습니까?\n진행 중인 작업이 있다면 저장되지 않을 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(localizations?.translate('common.cancel') ?? '취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: Text(localizations?.translate('app.exit') ?? '종료'),
          ),
        ],
      ),
    );
    
    return result ?? false;
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
      navigatorKey: navigatorKey,
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

// GlobalKey for accessing context from WindowListener
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

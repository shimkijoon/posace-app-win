import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'core/app_config.dart';
import 'core/utils/restart_widget.dart';
import 'app.dart';
import 'data/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Window Manager 초기화 (Windows 앱 창 제어)
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    minimumSize: Size(1024, 768),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  
  // 데이터베이스 초기화
  final database = AppDatabase();
  await database.init();
  
  runApp(
    RestartWidget(
      child: PosaceApp(database: database),
    ),
  );
}

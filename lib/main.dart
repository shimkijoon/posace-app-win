import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_config.dart';
import 'core/utils/restart_widget.dart';
import 'app.dart';
import 'data/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

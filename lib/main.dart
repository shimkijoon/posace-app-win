import 'package:flutter/material.dart';
import 'app.dart';
import 'data/local/app_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 데이터베이스 초기화
  final database = AppDatabase();
  await database.init();
  
  runApp(PosaceApp(database: database));
}

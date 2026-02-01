import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'POSAce';
  
  // Automatically use localhost in debug mode, production URL in release mode
  static String get apiBaseUrl {
    if (kDebugMode) {
      // Development mode - use localhost
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000/api/v1',
      );
    } else {
      // Production/Release mode - use production server
      return const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://api.posace.com/api/v1',
      );
    }
  }

  static String get backofficeBaseUrl {
    if (kDebugMode) {
      return const String.fromEnvironment(
        'BACKOFFICE_BASE_URL',
        defaultValue: 'http://localhost:3002',
      );
    } else {
      return const String.fromEnvironment(
        'BACKOFFICE_BASE_URL',
        defaultValue: 'https://backoffice.posace.com',
      );
    }
  }
  
  static const String supabaseUrl = 'https://wqjirowshlxfjcjmydfk.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Indxamlyb3dzaGx4Zmpjam15ZGZrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk0MjI0NjIsImV4cCI6MjA4NDk5ODQ2Mn0.9mDEINfZVcC1MiePGmm_RqGptBv2J6hsAhI3D-r5WDA';
}

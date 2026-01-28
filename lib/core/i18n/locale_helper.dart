import 'package:flutter/material.dart';
import '../storage/auth_storage.dart';

class LocaleHelper {
  /// 저장된 언어 설정을 읽어서 Locale 객체로 변환
  static Future<Locale> getLocale() async {
    final authStorage = AuthStorage();
    final languageCode = await authStorage.getUiLanguage() ?? 'ko';
    return _parseLocale(languageCode);
  }

  /// 언어 코드 문자열을 Locale 객체로 변환
  static Locale _parseLocale(String languageCode) {
    // 복합 언어 코드 처리
    if (languageCode.contains('-')) {
      final parts = languageCode.split('-');
      return Locale(parts[0], parts[1]);
    }
    
    // 단순 언어 코드
    return Locale(languageCode);
  }

  /// 지원되는 언어 목록
  static List<Locale> get supportedLocales => [
    Locale('ko'),
    Locale('ja'),
    Locale('zh', 'TW'),
    Locale('zh', 'HK'),
    Locale('en'),
  ];
}

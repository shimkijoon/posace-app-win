import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../storage/auth_storage.dart';

class LocaleHelper {
  /// 저장된 언어 설정을 읽어서 Locale 객체로 변환
  /// 우선순위: 1) POS 세션 언어, 2) 앱 전역 언어, 3) 시스템 로케일
  static Future<Locale> getLocale() async {
    final authStorage = AuthStorage();
    
    // 1순위: POS 세션 언어 (로그인 후 서버에서 받은 언어)
    final uiLanguage = await authStorage.getUiLanguage();
    if (uiLanguage != null && uiLanguage.isNotEmpty) {
      print('[LocaleHelper] Using POS session language: $uiLanguage');
      return _parseLocale(uiLanguage);
    }
    
    // 2순위: 앱 전역 언어 (사용자가 로그인 전 선택한 언어)
    final appLanguage = await authStorage.getAppLanguage();
    if (appLanguage != null && appLanguage.isNotEmpty) {
      print('[LocaleHelper] Using app language: $appLanguage');
      return _parseLocale(appLanguage);
    }
    
    // 3순위: 시스템 로케일
    final systemLocale = ui.PlatformDispatcher.instance.locale;
    final supportedLanguage = _getSupportedLanguage(systemLocale.languageCode);
    print('[LocaleHelper] Using system locale: ${systemLocale.languageCode} -> $supportedLanguage');
    
    return Locale(supportedLanguage);
  }
  
  /// 시스템 언어 코드를 지원되는 언어로 매핑
  static String _getSupportedLanguage(String languageCode) {
    switch (languageCode) {
      case 'ko':
        return 'ko';
      case 'ja':
        return 'ja';
      case 'zh':
        return 'zh';
      case 'en':
        return 'en';
      default:
        // 기본값: 한국어
        return 'ko';
    }
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

  static NumberFormat getCurrencyFormat(String countryCode) {
    switch (countryCode) {
      case 'KR':
        return NumberFormat.currency(locale: 'ko_KR', symbol: '₩', decimalDigits: 0);
      case 'JP':
        return NumberFormat.currency(locale: 'ja_JP', symbol: '¥', decimalDigits: 0);
      case 'TW':
        return NumberFormat.currency(locale: 'zh_TW', symbol: 'NT\$', decimalDigits: 0);
      case 'HK':
        return NumberFormat.currency(locale: 'zh_HK', symbol: 'HK\$', decimalDigits: 2);
      case 'SG':
        return NumberFormat.currency(locale: 'en_SG', symbol: 'S\$', decimalDigits: 2);
      case 'AU':
        return NumberFormat.currency(locale: 'en_AU', symbol: 'A\$', decimalDigits: 2);
      case 'US':
        return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
      default:
        return NumberFormat.currency(locale: 'en_US', symbol: '\$', decimalDigits: 2);
    }
  }

  static DateFormat getDateFormat(String countryCode) {
    switch (countryCode) {
      case 'KR':
      case 'JP':
      case 'TW':
      case 'HK':
        return DateFormat('yyyy-MM-dd HH:mm:ss');
      default:
        return DateFormat('dd/MM/yyyy HH:mm:ss');
    }
  }

  static String formatCurrency(num amount, String countryCode) {
    return getCurrencyFormat(countryCode).format(amount);
  }

  static String formatDate(DateTime date, String countryCode) {
    return getDateFormat(countryCode).format(date);
  }
}

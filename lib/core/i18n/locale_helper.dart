import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import '../storage/auth_storage.dart';

class LocaleHelper {
  /// 저장된 언어 설정을 읽어서 Locale 객체로 변환
  /// 우선순위: 1) 앱 전역 언어(사용자 선택), 2) POS 세션 언어(서버/매장), 3) 시스템 로케일, 4) 기본값(en)
  static Future<Locale> getLocale() async {
    final authStorage = AuthStorage();
    
    // 1순위: 앱 전역 언어 (사용자가 설정에서 선택한 언어)
    final appLanguage = await authStorage.getAppLanguage();
    if (appLanguage != null && appLanguage.isNotEmpty) {
      print('[LocaleHelper] Using app language: $appLanguage');
      return _parseLocale(appLanguage);
    }

    // 2순위: POS 세션 언어 (로그인 후 서버에서 받은 언어)
    final uiLanguage = await authStorage.getUiLanguage();
    if (uiLanguage != null && uiLanguage.isNotEmpty) {
      print('[LocaleHelper] Using POS session language: $uiLanguage');
      return _parseLocale(uiLanguage);
    }
    
    // 3순위: 시스템 로케일
    final systemLocale = ui.PlatformDispatcher.instance.locale;
    final localeFromSystem = _getSupportedLocaleFromSystem(systemLocale);
    print(
      '[LocaleHelper] Using system locale: ${systemLocale.languageCode}${systemLocale.countryCode != null ? '-${systemLocale.countryCode}' : ''} -> ${localeFromSystem.languageCode}${localeFromSystem.countryCode != null ? '-${localeFromSystem.countryCode}' : ''}',
    );

    return localeFromSystem;
  }
  
  /// 시스템 Locale을 지원되는 Locale로 매핑
  static Locale _getSupportedLocaleFromSystem(ui.Locale systemLocale) {
    final lang = systemLocale.languageCode;
    final country = systemLocale.countryCode;

    if (lang == 'ko') return const Locale('ko');
    if (lang == 'ja') return const Locale('ja');
    if (lang == 'en') return const Locale('en');

    if (lang == 'zh') {
      // 지원 파일은 zh-TW / zh-HK만 존재
      if (country == 'HK') return const Locale('zh', 'HK');
      return const Locale('zh', 'TW');
    }

    // 기본값: English
    return const Locale('en');
  }

  /// 언어 코드 문자열을 Locale 객체로 변환
  static Locale _parseLocale(String languageCode) {
    final code = languageCode.trim();

    // zh는 반드시 지역을 포함해야 함 (zh-TW, zh-HK)
    if (code == 'zh') {
      return const Locale('zh', 'TW');
    }
    if (code == 'zh-TW') return const Locale('zh', 'TW');
    if (code == 'zh-HK') return const Locale('zh', 'HK');

    // 영어 계열은 en.json 하나로 통합
    if (code == 'en' || code.startsWith('en-')) return const Locale('en');

    // 한국어/일본어
    if (code == 'ko') return const Locale('ko');
    if (code == 'ja') return const Locale('ja');

    // 알 수 없는 값은 English로
    return const Locale('en');
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

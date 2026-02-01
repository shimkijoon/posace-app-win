import 'package:flutter/material.dart';

import 'locale_helper.dart';

/// 앱 전역 Locale 상태를 관리합니다.
///
/// - 앱 시작 시 / 로그인(세션 언어 갱신) / 설정(앱 언어 변경) / 로그아웃 시
///   `reloadLocale()`을 호출하면 MaterialApp.locale 이 즉시 갱신됩니다.
final ValueNotifier<Locale?> appLocaleNotifier = ValueNotifier<Locale?>(null);

Future<void> reloadLocale() async {
  appLocaleNotifier.value = await LocaleHelper.getLocale();
}


import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../storage/auth_storage.dart';

class AppLocalizations {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  Future<bool> load() async {
    // 언어 코드 정규화
    String languageCode = locale.languageCode;
    if (locale.countryCode != null) {
      // 복합 언어 코드 처리
      if (languageCode == 'zh') {
        languageCode = locale.toString(); // zh-TW, zh-HK
      }
      // 영어는 통합 (en-SG, en-AU -> en)
      // 다른 언어는 단순 언어 코드 사용
    } else {
      // 단순 언어 코드는 그대로 사용 (ko, ja, en)
      languageCode = locale.languageCode;
    }

    try {
      print('[AppLocalizations] Loading translation file: lib/l10n/$languageCode.json for locale: ${locale.toString()}');
      
      // 번역 파일 로드
      String jsonString = await rootBundle.loadString('lib/l10n/$languageCode.json');
      _localizedStrings = json.decode(jsonString) as Map<String, dynamic>;
      print('[AppLocalizations] Successfully loaded ${_localizedStrings.length} top-level keys');
      return true;
    } catch (e) {
      print('[AppLocalizations] Failed to load $languageCode.json: $e');
      // Fallback to Korean if translation file not found
      try {
        print('[AppLocalizations] Falling back to ko.json');
        String jsonString = await rootBundle.loadString('lib/l10n/ko.json');
        _localizedStrings = json.decode(jsonString) as Map<String, dynamic>;
        print('[AppLocalizations] Successfully loaded fallback ko.json');
        return true;
      } catch (fallbackError) {
        print('[AppLocalizations] Failed to load fallback ko.json: $fallbackError');
        _localizedStrings = {};
        return false;
      }
    }
  }

  String translate(String key, {Map<String, String>? args}) {
    // Handle nested keys like "home.todayStoreStatus"
    dynamic value = _localizedStrings;
    final keys = key.split('.');
    
    for (final k in keys) {
      if (value is Map<String, dynamic>) {
        final nextValue = value[k];
        if (nextValue == null) {
          print('[AppLocalizations] Translation not found for key: $key');
          return key; // Fallback to key if translation not found
        }
        value = nextValue;
      } else {
        print('[AppLocalizations] Invalid structure for key: $key');
        return key; // Invalid structure
      }
    }
    
    // Convert to String (handle both String and other types)
    final String result;
    if (value is String) {
      result = value;
    } else {
      result = value.toString();
    }
    
    // Simple argument replacement: {argName} -> value
    if (args != null) {
      String finalResult = result;
      args.forEach((argKey, argValue) {
        finalResult = finalResult.replaceAll('{$argKey}', argValue);
      });
      return finalResult;
    }

    return result;
  }

  // Convenience getters for common translations
  String get appName => translate('app.name');
  String get sales => translate('sales.title');
  String get storeInfo => translate('store.info');
  String get storeName => translate('store.name');
  String get businessNumber => translate('store.businessNumber');
  String get phone => translate('store.phone');
  String get address => translate('store.address');
  String get operatingStatus => translate('store.operatingStatus');
  String get operating => translate('store.operating');
  String get closed => translate('store.closed');
  String get closeBusiness => translate('store.closeBusiness');
  String get managementTools => translate('home.managementTools');
  String get weeklySalesTrend => translate('home.weeklySalesTrend');
  String get todayStoreStatus => translate('home.todayStoreStatus');
  String get startSale => translate('home.startSale');
  String get tableOrder => translate('home.tableOrder');
  String get salesHistory => translate('home.salesHistory');
  String get posSettings => translate('home.posSettings');
  String get logout => translate('auth.logout');
  String get cartEmpty => translate('sales.cartEmpty');
  String get subtotal => translate('sales.subtotal');
  String get discountAmount => translate('sales.discountAmount');
  String get totalPayment => translate('sales.totalPayment');
  String get proceedToPayment => translate('sales.proceedToPayment');
  String get searchProduct => translate('sales.searchProduct');
  String get all => translate('sales.all');
  String get discount => translate('sales.discount');
  String get member => translate('sales.member');
  String get cancelTransaction => translate('sales.cancelTransaction');
  String get holdTransaction => translate('sales.holdTransaction');
  String get remaining => translate('sales.remaining');
  String get qty => translate('sales.qty');
  String get name => translate('sales.name');
  String get price => translate('sales.price');
  String get total => translate('sales.total');
  String get cart => translate('sales.cart');
  String get clear => translate('sales.clear');
  
  // Receipt translations
  String get receiptHeader => translate('receipt.header');
  String get receiptBusinessNumber => translate('receipt.businessNumber');
  String get receiptDateTime => translate('receipt.dateTime');
  String get receiptTransactionNumber => translate('receipt.transactionNumber');
  String get receiptProductName => translate('sales.productName');
  String get receiptQty => translate('sales.qty');
  String get receiptAmount => translate('receipt.amount');
  String get receiptPaymentMethod => translate('receipt.paymentMethod');
  String get receiptChange => translate('receipt.change');
  String get receiptThankYou => translate('receipt.thankYouMessage');
  
  // Session/Home getters
  String get enterOpeningAmount => translate('home.enterOpeningAmount');
  String get enterClosingAmount => translate('session.enterClosingAmount');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['ko', 'ja', 'zh', 'en'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

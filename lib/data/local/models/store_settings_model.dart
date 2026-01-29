import 'dart:convert';

class StoreSettingsModel {
  final String id;
  final String storeId;
  final String receiptTemplateId;
  final String uiLanguage;
  final String taxCalculationMethod;
  final bool defaultTaxInclusive;
  final String discountDisplayFormat;
  final bool allowMultipleDiscounts;
  final String? receiptHeader;
  final String? receiptFooter;
  final bool receiptShowTaxDetails;
  final bool receiptShowDiscountDetails;
  final ReceiptTemplateModel? receiptTemplate;

  StoreSettingsModel({
    required this.id,
    required this.storeId,
    required this.receiptTemplateId,
    required this.uiLanguage,
    required this.taxCalculationMethod,
    required this.defaultTaxInclusive,
    required this.discountDisplayFormat,
    required this.allowMultipleDiscounts,
    this.receiptHeader,
    this.receiptFooter,
    required this.receiptShowTaxDetails,
    required this.receiptShowDiscountDetails,
    this.receiptTemplate,
  });

  factory StoreSettingsModel.fromMap(Map<String, dynamic> map) {
    return StoreSettingsModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      receiptTemplateId: map['receiptTemplateId'] as String,
      uiLanguage: map['uiLanguage'] as String,
      taxCalculationMethod: map['taxCalculationMethod'] as String,
      defaultTaxInclusive: map['defaultTaxInclusive'] as bool,
      discountDisplayFormat: map['discountDisplayFormat'] as String,
      allowMultipleDiscounts: map['allowMultipleDiscounts'] as bool,
      receiptHeader: map['receiptHeader'] as String?,
      receiptFooter: map['receiptFooter'] as String?,
      receiptShowTaxDetails: map['receiptShowTaxDetails'] as bool,
      receiptShowDiscountDetails: map['receiptShowDiscountDetails'] as bool,
      receiptTemplate: map['receiptTemplate'] != null 
          ? ReceiptTemplateModel.fromMap(map['receiptTemplate'] as Map<String, dynamic>)
          : null,
    );
  }
}

class ReceiptTemplateModel {
  final String id;
  final String name;
  final String country;
  final Map<String, dynamic> layout;
  final Map<String, dynamic>? style;
  final Map<String, dynamic> fields;

  ReceiptTemplateModel({
    required this.id,
    required this.name,
    required this.country,
    required this.layout,
    this.style,
    required this.fields,
  });

  factory ReceiptTemplateModel.fromMap(Map<String, dynamic> map) {
    return ReceiptTemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      country: map['country'] as String,
      layout: map['layout'] as Map<String, dynamic>,
      style: map['style'] as Map<String, dynamic>?,
      fields: map['fields'] as Map<String, dynamic>,
    );
  }
}

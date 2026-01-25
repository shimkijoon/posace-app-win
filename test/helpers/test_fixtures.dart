import 'package:posace_app_win/data/local/models.dart';
import 'package:posace_app_win/data/local/models/taxes_models.dart';
import 'package:posace_app_win/data/local/models/options_models.dart';
import 'package:posace_app_win/data/local/models/employee_model.dart';
import 'package:posace_app_win/data/local/models/session_model.dart';
import 'package:posace_app_win/data/local/models/payment_model.dart';

// Import PosSessionModel
import 'package:posace_app_win/data/local/models/session_model.dart' as session_models;

final testStoreId = 'test-store-1';
final testPosId = 'test-pos-1';
final now = DateTime.now();

// Tax Fixtures
TaxModel createInclusiveTax({
  String? id,
  double rate = 10.0,
  String name = 'VAT 10%',
}) {
  return TaxModel(
    id: id ?? 'tax-inclusive',
    storeId: testStoreId,
    name: name,
    rate: rate,
    isInclusive: true,
    createdAt: now,
    updatedAt: now,
  );
}

TaxModel createExclusiveTax({
  String? id,
  double rate = 5.0,
  String name = 'Sales Tax 5%',
}) {
  return TaxModel(
    id: id ?? 'tax-exclusive',
    storeId: testStoreId,
    name: name,
    rate: rate,
    isInclusive: false,
    createdAt: now,
    updatedAt: now,
  );
}

// Category Fixtures
CategoryModel createCategory({
  String? id,
  String name = 'Test Category',
  int sortOrder = 0,
  bool allowProductDiscount = true,
}) {
  return CategoryModel(
    id: id ?? 'category-1',
    storeId: testStoreId,
    name: name,
    sortOrder: sortOrder,
    allowProductDiscount: allowProductDiscount,
    createdAt: now,
    updatedAt: now,
  );
}

// Product Fixtures
ProductModel createProduct({
  String? id,
  String? categoryId,
  String name = 'Test Product',
  int price = 10000,
  String type = 'SINGLE',
  List<TaxModel>? taxes,
  List<ProductOptionGroupModel>? optionGroups,
}) {
  return ProductModel(
    id: id ?? 'product-1',
    storeId: testStoreId,
    categoryId: categoryId ?? 'category-1',
    name: name,
    type: type,
    price: price,
    stockEnabled: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    taxes: taxes ?? [],
    optionGroups: optionGroups ?? [],
  );
}

// Discount Fixtures
DiscountModel createProductDiscount({
  String? id,
  String? targetId,
  String name = 'Product Discount',
  int rateOrAmount = 10,
  String method = 'PERCENTAGE',
  int priority = 0,
  List<String>? productIds,
}) {
  return DiscountModel(
    id: id ?? 'discount-product-1',
    storeId: testStoreId,
    type: 'PRODUCT',
    targetId: targetId,
    name: name,
    rateOrAmount: rateOrAmount,
    priority: priority,
    productIds: productIds ?? [],
    status: 'ACTIVE',
    method: method,
    createdAt: now,
    updatedAt: now,
  );
}

DiscountModel createCategoryDiscount({
  String? id,
  List<String>? categoryIds,
  String name = 'Category Discount',
  int rateOrAmount = 15,
  String method = 'PERCENTAGE',
  int priority = 0,
}) {
  return DiscountModel(
    id: id ?? 'discount-category-1',
    storeId: testStoreId,
    type: 'CATEGORY',
    name: name,
    rateOrAmount: rateOrAmount,
    priority: priority,
    categoryIds: categoryIds ?? ['category-1'],
    status: 'ACTIVE',
    method: method,
    createdAt: now,
    updatedAt: now,
  );
}

DiscountModel createCartDiscount({
  String? id,
  String name = 'Cart Discount',
  int rateOrAmount = 5,
  String method = 'PERCENTAGE',
}) {
  return DiscountModel(
    id: id ?? 'discount-cart-1',
    storeId: testStoreId,
    type: 'CART',
    name: name,
    rateOrAmount: rateOrAmount,
    status: 'ACTIVE',
    method: method,
    createdAt: now,
    updatedAt: now,
  );
}

// Option Fixtures
ProductOptionGroupModel createOptionGroup({
  String? id,
  String name = 'Size',
  bool isRequired = false,
  bool isMultiSelect = false,
  List<ProductOptionModel>? options,
}) {
  return ProductOptionGroupModel(
    id: id ?? 'option-group-1',
    productId: 'product-1',
    name: name,
    isRequired: isRequired,
    isMultiSelect: isMultiSelect,
    sortOrder: 0,
    options: options ?? [],
  );
}

ProductOptionModel createOption({
  String? id,
  String? groupId,
  String name = 'Large',
  double priceAdjustment = 500.0,
}) {
  return ProductOptionModel(
    id: id ?? 'option-1',
    groupId: groupId ?? 'option-group-1',
    name: name,
    priceAdjustment: priceAdjustment,
    sortOrder: 0,
  );
}

// Employee Fixtures
EmployeeModel createEmployee({
  String? id,
  String name = 'Test Employee',
  String role = 'CASHIER',
}) {
  return EmployeeModel(
    id: id ?? 'employee-1',
    storeId: testStoreId,
    name: name,
    role: role,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

// Session Fixtures
session_models.PosSessionModel createSession({
  String? id,
  int openingAmount = 100000,
  String status = 'OPEN',
}) {
  return session_models.PosSessionModel(
    id: id ?? 'session-1',
    storeId: testStoreId,
    posId: testPosId,
    openingAmount: openingAmount,
    status: status,
    createdAt: now,
  );
}

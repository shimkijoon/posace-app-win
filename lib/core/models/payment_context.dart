import 'package:flutter/material.dart';
import '../models/cart.dart';
import '../../data/local/models.dart';

/// 결제 컨텍스트 저장/복원을 위한 클래스
class PaymentContext {
  final Cart cart;
  final Set<String> selectedDiscountIds;
  final MemberModel? selectedMember;
  final double? customAmount;
  final String? paymentMethod;
  final String? tableId;

  PaymentContext({
    required this.cart,
    required this.selectedDiscountIds,
    this.selectedMember,
    this.customAmount,
    this.paymentMethod,
    this.tableId,
  });

  /// JSON으로 변환 (필요시 로컬 저장용)
  Map<String, dynamic> toJson() {
    return {
      'cart': cart.toJson(),
      'selectedDiscountIds': selectedDiscountIds.toList(),
      'selectedMember': selectedMember?.toMap(),
      'customAmount': customAmount,
      'paymentMethod': paymentMethod,
      'tableId': tableId,
    };
  }

  /// JSON에서 복원 (필요시)
  static PaymentContext fromJson(Map<String, dynamic> json) {
    return PaymentContext(
      cart: Cart.fromJson(json['cart']),
      selectedDiscountIds: Set<String>.from(json['selectedDiscountIds'] ?? []),
      selectedMember: json['selectedMember'] != null
          ? MemberModel.fromMap(json['selectedMember'])
          : null,
      customAmount: json['customAmount'],
      paymentMethod: json['paymentMethod'],
      tableId: json['tableId'],
    );
  }
}

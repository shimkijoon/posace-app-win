class SalePaymentModel {
  final String id;
  final String saleId;
  final String method;
  final int amount;
  final String? cardApproval;
  final String? cardLast4;

  SalePaymentModel({
    required this.id,
    required this.saleId,
    required this.method,
    required this.amount,
    this.cardApproval,
    this.cardLast4,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'saleId': saleId,
      'method': method,
      'amount': amount,
      'cardApproval': cardApproval,
      'cardLast4': cardLast4,
    };
  }

  factory SalePaymentModel.fromMap(Map<String, dynamic> map) {
    return SalePaymentModel(
      id: map['id'] as String,
      saleId: map['saleId'] as String,
      method: map['method'] as String,
      amount: (map['amount'] as num).round(),
      cardApproval: map['cardApproval'] as String?,
      cardLast4: map['cardLast4'] as String?,
    );
  }
}

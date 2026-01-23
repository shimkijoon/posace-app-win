class PosSessionModel {
  final String id;
  final String storeId;
  final String posId;
  final String? employeeId;
  final int openingAmount;
  final int? closingAmount;
  final int? expectedAmount;
  final int? variance;
  final String status;
  final DateTime createdAt;
  final DateTime? closedAt;

  PosSessionModel({
    required this.id,
    required this.storeId,
    required this.posId,
    this.employeeId,
    required this.openingAmount,
    this.closingAmount,
    this.expectedAmount,
    this.variance,
    required this.status,
    required this.createdAt,
    this.closedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'posId': posId,
      'employeeId': employeeId,
      'openingAmount': openingAmount,
      'closingAmount': closingAmount,
      'expectedAmount': expectedAmount,
      'variance': variance,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'closedAt': closedAt?.toIso8601String(),
    };
  }

  factory PosSessionModel.fromMap(Map<String, dynamic> map) {
    return PosSessionModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      posId: map['posId'] as String,
      employeeId: map['employeeId'] as String?,
      openingAmount: (map['openingAmount'] as num).round(),
      closingAmount: map['closingAmount'] != null ? (map['closingAmount'] as num).round() : null,
      expectedAmount: map['expectedAmount'] != null ? (map['expectedAmount'] as num).round() : null,
      variance: map['variance'] != null ? (map['variance'] as num).round() : null,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      closedAt: map['closedAt'] != null ? DateTime.parse(map['closedAt'] as String) : null,
    );
  }
}

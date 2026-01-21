class TaxModel {
  final String id;
  final String storeId;
  final String name;
  final double rate;
  final bool isInclusive;
  final DateTime createdAt;
  final DateTime updatedAt;

  TaxModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.rate,
    required this.isInclusive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storeId': storeId,
      'name': name,
      'rate': rate,
      'isInclusive': isInclusive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TaxModel.fromMap(Map<String, dynamic> map) {
    return TaxModel(
      id: map['id'] as String,
      storeId: map['storeId'] as String,
      name: map['name'] as String,
      rate: map['rate'] is String
          ? double.parse(map['rate'] as String)
          : (map['rate'] as num).toDouble(),
      isInclusive: map['isInclusive'] is bool
          ? map['isInclusive'] as bool
          : (map['isInclusive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

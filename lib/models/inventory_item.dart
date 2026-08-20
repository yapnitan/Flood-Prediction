/// One item in a household's emergency supply inventory — e.g. "Bottled
/// water", 12 units, category "Water & Food".
class InventoryItem {
  const InventoryItem({
    this.id,
    this.accountId,
    required this.name,
    this.category = 'Other',
    this.quantity = 1,
    this.unit,
    this.expiryDate,
    this.createdAt,
  });

  final String? id;
  final String? accountId;
  final String name;
  final String category;
  final int quantity;
  final String? unit;
  final DateTime? expiryDate;
  final DateTime? createdAt;

  static const List<String> categoryOptions = [
    'Water & Food',
    'First Aid',
    'Tools & Lighting',
    'Documents',
    'Clothing',
    'Other',
  ];

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String?,
    accountId: json['account_id'] as String?,
    name: json['name'] as String,
    category: json['category'] as String? ?? 'Other',
    quantity: json['quantity'] as int? ?? 1,
    unit: json['unit'] as String?,
    expiryDate: json['expiry_date'] != null
        ? DateTime.parse(json['expiry_date'] as String)
        : null,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (accountId != null) 'account_id': accountId,
    'name': name,
    'category': category,
    'quantity': quantity,
    'unit': unit,
    'expiry_date': expiryDate?.toIso8601String().split('T').first,
  };

  InventoryItem copyWith({
    String? name,
    String? category,
    int? quantity,
    String? unit,
    DateTime? expiryDate,
  }) => InventoryItem(
    id: id,
    accountId: accountId,
    name: name ?? this.name,
    category: category ?? this.category,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    expiryDate: expiryDate ?? this.expiryDate,
    createdAt: createdAt,
  );
}

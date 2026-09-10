
class EmergencyContact {
  const EmergencyContact({
    this.id,
    this.accountId,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.notes,
    this.createdAt,
  });

  final String? id;
  final String? accountId;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final String? notes;
  final DateTime? createdAt;

  static const List<String> relationshipOptions = [
    'Family',
    'Neighbor',
    'Doctor',
    'Emergency Service',
    'Other',
  ];

  factory EmergencyContact.fromJson(Map<String, dynamic> json) => EmergencyContact(
    id: json['id'] as String?,
    accountId: json['account_id'] as String?,
    name: json['name'] as String,
    phoneNumber: json['phone_number'] as String,
    relationship: json['relationship'] as String?,
    notes: json['notes'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (accountId != null) 'account_id': accountId,
    'name': name,
    'phone_number': phoneNumber,
    'relationship': relationship,
    'notes': notes,
  };

  EmergencyContact copyWith({
    String? name,
    String? phoneNumber,
    String? relationship,
    String? notes,
  }) => EmergencyContact(
    id: id,
    accountId: accountId,
    name: name ?? this.name,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    relationship: relationship ?? this.relationship,
    notes: notes ?? this.notes,
    createdAt: createdAt,
  );
}

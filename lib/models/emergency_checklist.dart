/// A named group of [ChecklistItem]s owned by one account — e.g. "Home
/// go-bag" or "Car emergency kit". Users can keep several.
class EmergencyChecklist {
  const EmergencyChecklist({
    this.id,
    this.accountId,
    required this.title,
    this.createdAt,
  });

  final String? id;
  final String? accountId;
  final String title;
  final DateTime? createdAt;

  factory EmergencyChecklist.fromJson(Map<String, dynamic> json) => EmergencyChecklist(
    id: json['id'] as String?,
    accountId: json['account_id'] as String?,
    title: json['title'] as String,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (accountId != null) 'account_id': accountId,
    'title': title,
  };

  EmergencyChecklist copyWith({String? title}) => EmergencyChecklist(
    id: id,
    accountId: accountId,
    title: title ?? this.title,
    createdAt: createdAt,
  );
}

/// One item on an [EmergencyChecklist] — e.g. "Torchlight", "First aid kit".
class ChecklistItem {
  const ChecklistItem({
    this.id,
    this.checklistId,
    required this.label,
    this.isChecked = false,
    this.sortOrder = 0,
    this.createdAt,
  });

  final String? id;
  final String? checklistId;
  final String label;
  final bool isChecked;
  final int sortOrder;
  final DateTime? createdAt;

  factory ChecklistItem.fromJson(Map<String, dynamic> json) => ChecklistItem(
    id: json['id'] as String?,
    checklistId: json['checklist_id'] as String?,
    label: json['label'] as String,
    isChecked: json['is_checked'] as bool? ?? false,
    sortOrder: json['sort_order'] as int? ?? 0,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    if (checklistId != null) 'checklist_id': checklistId,
    'label': label,
    'is_checked': isChecked,
    'sort_order': sortOrder,
  };

  ChecklistItem copyWith({String? label, bool? isChecked}) => ChecklistItem(
    id: id,
    checklistId: checklistId,
    label: label ?? this.label,
    isChecked: isChecked ?? this.isChecked,
    sortOrder: sortOrder,
    createdAt: createdAt,
  );
}

class HelperDistrictAssignment {
  const HelperDistrictAssignment({
    this.id,
    required this.helperId,
    required this.state,
    required this.district,
    this.status = 'active',
    this.assignedAt,
    this.startDate,
    this.endDate,
  });

  final String? id;
  final String helperId;
  final String state;
  final String district;
  final String status;
  final DateTime? assignedAt;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isActive => status == 'active';

  factory HelperDistrictAssignment.fromJson(Map<String, dynamic> json) => HelperDistrictAssignment(
    id: json['id'] as String?,
    helperId: json['helper_id'] as String,
    state: json['state'] as String,
    district: json['district'] as String,
    status: json['status'] as String? ?? 'active',
    assignedAt: json['assigned_at'] != null ? DateTime.parse(json['assigned_at'] as String) : null,
    startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
    endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'helper_id': helperId,
    'state': state,
    'district': district,
    'status': status,
    'start_date': startDate?.toIso8601String().split('T').first,
    'end_date': endDate?.toIso8601String().split('T').first,
  };
}

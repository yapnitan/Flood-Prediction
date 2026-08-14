class RepairRequest {
  const RepairRequest({
    this.id,
    this.requesterId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.assistanceType,
    this.damageDescription,
    this.contactNumber,
    this.photoPaths = const [],
    this.status = 'pending',
    this.priority = 'medium',
    this.assignedHelperId,
    this.facilityId,
    this.details = const {},
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? requesterId;
  final String locationName;
  final double latitude;
  final double longitude;
  final String assistanceType;
  final String? damageDescription;
  final String? contactNumber;
  /// Per-assistance-type structured fields — see
  /// lib/models/assistance_field_spec.dart for what each type stores here.
  final Map<String, dynamic> details;
  final List<String> photoPaths;
  final String status;
  final String priority;
  final String? assignedHelperId;
  final String? facilityId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RepairRequest.fromJson(Map<String, dynamic> json) => RepairRequest(
    id: json['id'] as String?,
    requesterId: json['requester_id'] as String?,
    locationName: json['location_name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    assistanceType: json['assistance_type'] as String,
    damageDescription: json['damage_description'] as String?,
    contactNumber: json['contact_number'] as String?,
    photoPaths: (json['photo_paths'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? const [],
    status: json['status'] as String? ?? 'pending',
    priority: json['priority'] as String? ?? 'medium',
    assignedHelperId: json['assigned_helper_id'] as String?,
    facilityId: json['facility_id'] as String?,
    details: json['details'] != null
        ? Map<String, dynamic>.from(json['details'] as Map)
        : const {},
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String) : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String) : null,
  );

  static String suggestedPriority(String assistanceType) {
    switch (assistanceType) {
      case 'Medical Assistance':
        return 'urgent';
      case 'Temporary Shelter':
      case 'Food & Water Supply':
        return 'high';
      case 'Structural Repair':
        return 'medium';
      case 'Financial Aid':
        return 'low';
      default:
        return 'medium';
    }
  }

  static const Map<String, int> priorityRank = {
    'urgent': 0, 'high': 1, 'medium': 2, 'low': 3,
  };

  int get priorityWeight => priorityRank[priority] ?? priorityRank.length;

  static int comparePriority(RepairRequest a, RepairRequest b) {
    final byPriority = a.priorityWeight.compareTo(b.priorityWeight);
    if (byPriority != 0) return byPriority;
    final aCreated = a.createdAt;
    final bCreated = b.createdAt;
    if (aCreated == null || bCreated == null) return 0;
    return bCreated.compareTo(aCreated);
  }

  // --- Fulfillment mode: drives which UI (map/facility/nothing) each role sees ---
  static const Map<String, FulfillmentMode> _fulfillmentByType = {
    'Structural Repair': FulfillmentMode.field,
    'Medical Assistance': FulfillmentMode.field,
    'Temporary Shelter': FulfillmentMode.facility,
    'Food & Water Supply': FulfillmentMode.facility,
    'Financial Aid': FulfillmentMode.remote,
    'Other': FulfillmentMode.field,
  };

  static FulfillmentMode fulfillmentModeFor(String assistanceType) =>
      _fulfillmentByType[assistanceType] ?? FulfillmentMode.field;

  FulfillmentMode get fulfillmentMode => fulfillmentModeFor(assistanceType);

  /// Which facility_type an admin should be offered when this request's
  /// fulfillment mode is `facility`. Null for field/remote requests.
  static const Map<String, String> _facilityTypeByAssistanceType = {
    'Temporary Shelter': 'shelter',
    'Food & Water Supply': 'distribution_center',
  };

  String? get requiredFacilityType => _facilityTypeByAssistanceType[assistanceType];

  /// Medical Assistance requests the requester marked critical — always
  /// forced to 'urgent' priority on submit (see RepairRequestService.submit)
  /// and highlighted in admin/helper lists, per CLAUDE.md Task 10 spec.
  bool get isCriticalMedical => assistanceType == 'Medical Assistance' && details['is_critical'] == true;

  Map<String, dynamic> toJson() => {
    'requester_id': requesterId,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'assistance_type': assistanceType,
    'damage_description': damageDescription,
    'contact_number': contactNumber,
    'photo_paths': photoPaths,
    'priority': priority,
    'facility_id': facilityId,
    'details': details,
  };

  RepairRequest copyWith({
    String? status,
    String? priority,
    String? assignedHelperId,
    String? facilityId,
    String? assistanceType,
    String? damageDescription,
    List<String>? photoPaths,
    Map<String, dynamic>? details,
  }) {
    return RepairRequest(
      id: id,
      requesterId: requesterId,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      assistanceType: assistanceType ?? this.assistanceType,
      damageDescription: damageDescription ?? this.damageDescription,
      contactNumber: contactNumber,
      photoPaths: photoPaths ?? this.photoPaths,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedHelperId: assignedHelperId ?? this.assignedHelperId,
      facilityId: facilityId ?? this.facilityId,
      details: details ?? this.details,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

enum FulfillmentMode { field, facility, remote }
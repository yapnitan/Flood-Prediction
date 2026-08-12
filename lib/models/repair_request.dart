class RepairRequest {
  const RepairRequest({
    this.id,
    this.requesterId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.assistanceType,
    required this.damageDescription,
    this.contactNumber,
    this.photoPaths = const [],
    this.status = 'pending',
    this.priority = 'medium',
    this.assignedHelperId,
    this.shelterName,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String? requesterId;
  final String locationName;
  final double latitude;
  final double longitude;
  final String assistanceType;
  final String damageDescription;
  final String? contactNumber;
  final List<String> photoPaths;
  final String status;
  final String priority;
  final String? assignedHelperId;
  final String? shelterName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory RepairRequest.fromJson(Map<String, dynamic> json) => RepairRequest(
    id: json['id'] as String?,
    requesterId: json['requester_id'] as String?,
    locationName: json['location_name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    assistanceType: json['assistance_type'] as String,
    damageDescription: json['damage_description'] as String,
    contactNumber: json['contact_number'] as String?,
    photoPaths:
    (json['photo_paths'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ??
        const [],
    status: json['status'] as String? ?? 'pending',
    priority: json['priority'] as String? ?? 'medium',
    assignedHelperId: json['assigned_helper_id'] as String?,
    shelterName: json['shelter_name'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.parse(json['updated_at'] as String)
        : null,
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
    'shelter_name': shelterName,
  };

  RepairRequest copyWith({
    String? status,
    String? priority,
    String? assignedHelperId,
    String? shelterName,
    String? assistanceType,
    String? damageDescription,
    List<String>? photoPaths,
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
      shelterName: shelterName ?? this.shelterName,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
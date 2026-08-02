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
    this.status = 'Pending',
    this.createdAt,
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
  final DateTime? createdAt;

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
    status: json['status'] as String? ?? 'Pending',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'requester_id': requesterId,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'assistance_type': assistanceType,
    'damage_description': damageDescription,
    'contact_number': contactNumber,
    'photo_paths': photoPaths,
  };
}

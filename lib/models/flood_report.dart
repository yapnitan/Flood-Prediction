class FloodReport {
  const FloodReport({
    this.id,
    this.reporterId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    this.state,
    this.district,
    required this.floodType,
    required this.waterLevel,
    required this.observedAt,
    required this.description,
    this.contactNumber,
    this.photoPaths = const [],
    this.status = 'submitted',
    this.createdAt,
  });

  final String? id;
  final String? reporterId;
  final String locationName;
  final double latitude;
  final double longitude;

  final String? state;
  final String? district;
  final String floodType;
  final String waterLevel;
  final DateTime observedAt;
  final String description;
  final String? contactNumber;
  final List<String> photoPaths;
  final String status;
  final DateTime? createdAt;

  bool get isVerified => status == 'verified';

  factory FloodReport.fromJson(Map<String, dynamic> json) => FloodReport(
    id: json['id'] as String?,
    reporterId: json['reporter_id'] as String?,
    locationName: json['location_name'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    state: json['state'] as String?,
    district: json['district'] as String?,
    floodType: json['flood_type'] as String,
    waterLevel: json['water_level'] as String,
    observedAt: DateTime.parse(json['observed_at'] as String).toLocal(),
    description: json['description'] as String,
    contactNumber: json['contact_number'] as String?,
    photoPaths:
        (json['photo_paths'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const [],
    status: json['status'] as String? ?? 'submitted',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String).toLocal()
        : null,
  );

  Map<String, dynamic> toJson() => {
    'reporter_id': reporterId,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'state': state,
    'district': district,
    'flood_type': floodType,
    'water_level': waterLevel,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'description': description,
    'contact_number': contactNumber,
    'photo_paths': photoPaths,
  };

  FloodReport copyWith({String? status}) {
    return FloodReport(
      id: id,
      reporterId: reporterId,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      state: state,
      district: district,
      floodType: floodType,
      waterLevel: waterLevel,
      observedAt: observedAt,
      description: description,
      contactNumber: contactNumber,
      photoPaths: photoPaths,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

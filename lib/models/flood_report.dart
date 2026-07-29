class FloodReport {
  const FloodReport({
    this.reporterId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.floodType,
    required this.waterLevel,
    required this.observedAt,
    required this.description,
    this.contactNumber,
    this.photoPaths = const [],
  });

  final String? reporterId;
  final String locationName;
  final double latitude;
  final double longitude;
  final String floodType;
  final String waterLevel;
  final DateTime observedAt;
  final String description;
  final String? contactNumber;
  final List<String> photoPaths;

  Map<String, dynamic> toJson() => {
    'reporter_id': reporterId,
    'location_name': locationName,
    'latitude': latitude,
    'longitude': longitude,
    'flood_type': floodType,
    'water_level': waterLevel,
    'observed_at': observedAt.toUtc().toIso8601String(),
    'description': description,
    'contact_number': contactNumber,
    'photo_paths': photoPaths,
  };
}

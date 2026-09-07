class Facility {
  const Facility({
    this.id,
    required this.name,
    required this.facilityType,
    required this.latitude,
    required this.longitude,
    this.address,
    this.state,
    this.district,
    this.capacity,
    this.contactNumber,
    this.isActive = true,
    this.createdAt,
  });

  final String? id;
  final String name;
  final String facilityType; // 'shelter' | 'distribution_center' | 'medical_station'
  final double latitude;
  final double longitude;
  final String? address;

  /// Derived from the location the admin picked when creating or editing the
  /// facility (search suggestion, map pick, or "Use Current Location" reverse
  /// geocoding) — editable afterwards on the form.
  final String? state;
  final String? district;
  final int? capacity;
  final String? contactNumber;
  final bool isActive;
  final DateTime? createdAt;

  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
    id: json['id'] as String?,
    name: json['name'] as String,
    facilityType: json['facility_type'] as String,
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    address: json['address'] as String?,
    state: json['state'] as String?,
    district: json['district'] as String?,
    capacity: json['capacity'] as int?,
    contactNumber: json['contact_number'] as String?,
    isActive: json['is_active'] as bool? ?? true,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'facility_type': facilityType,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'state': state,
    'district': district,
    'capacity': capacity,
    'contact_number': contactNumber,
    'is_active': isActive,
  };

  Facility copyWith({
    String? name,
    String? facilityType,
    double? latitude,
    double? longitude,
    String? address,
    String? state,
    String? district,
    int? capacity,
    String? contactNumber,
    bool? isActive,
  }) {
    return Facility(
      id: id,
      name: name ?? this.name,
      facilityType: facilityType ?? this.facilityType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      state: state ?? this.state,
      district: district ?? this.district,
      capacity: capacity ?? this.capacity,
      contactNumber: contactNumber ?? this.contactNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  static const Map<String, String> typeLabels = {
    'shelter': 'Shelter',
    'distribution_center': 'Distribution Center',
    'medical_station': 'Medical Station',
  };

  String get typeLabel => typeLabels[facilityType] ?? facilityType;
}
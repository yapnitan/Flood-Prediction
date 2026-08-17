class Property {
  const Property({
    this.id,
    this.accountId,
    this.address,
    required this.lat,
    required this.lng,
    this.propertyType,
    this.floors,
    this.estimatedValue,
    this.riskLevel,
    this.createdAt,
  });

  final int? id;
  final String? accountId;
  final String? address;
  final double lat;
  final double lng;
  final String? propertyType;
  final int? floors;
  final double? estimatedValue;
  final String? riskLevel;
  final DateTime? createdAt;

  factory Property.fromJson(Map<String, dynamic> json) => Property(
    id: json['id'] as int?,
    accountId: json['account_id'] as String?,
    address: json['address'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    propertyType: json['property_type'] as String?,
    floors: json['floors'] as int?,
    estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
    riskLevel: json['risk_level'] as String?,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'address': address,
    'lat': lat,
    'lng': lng,
    'property_type': propertyType,
    'floors': floors,
    'estimated_value': estimatedValue,
    'risk_level': riskLevel,
  };

  /// Short label for a selection dropdown — falls back to coordinates when
  /// there's no address on file.
  String get displayLabel {
    final type = propertyType;
    final addr = address;
    if (addr != null && addr.isNotEmpty) {
      return type != null ? '$addr ($type)' : addr;
    }
    return type ?? 'Property at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}

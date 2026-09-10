class Property {
  const Property({
    this.id,
    this.accountId,
    this.label,
    this.address,
    required this.lat,
    required this.lng,
    this.state,
    this.district,
    this.postcode,
    this.propertyType,
    this.floors,
    this.estimatedValue,
    this.riskLevel,
    this.archivedAt,
    this.createdAt,
  });

  final int? id;
  final String? accountId;

  /// User-chosen name for this saved address — "Home"/"Work"/"Other" or a
  /// custom label — shown wherever the resident picks among their
  /// properties (risk simulator, Asset Loss Report address selection).
  final String? label;
  final String? address;
  final double lat;
  final double lng;
  final String? state;
  final String? district;
  final String? postcode;
  final String? propertyType;
  final int? floors;
  final double? estimatedValue;
  final String? riskLevel;

  /// Set when the user "deleted" this address but it's still referenced by
  /// asset-loss reports — the row is kept, just hidden from their list.
  final DateTime? archivedAt;
  bool get isArchived => archivedAt != null;
  final DateTime? createdAt;

  factory Property.fromJson(Map<String, dynamic> json) => Property(
    id: json['id'] as int?,
    accountId: json['account_id'] as String?,
    label: json['label'] as String?,
    address: json['address'] as String?,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    state: json['state'] as String?,
    district: json['district'] as String?,
    postcode: json['postcode'] as String?,
    propertyType: json['property_type'] as String?,
    floors: json['floors'] as int?,
    estimatedValue: (json['estimated_value'] as num?)?.toDouble(),
    riskLevel: json['risk_level'] as String?,
    archivedAt: json['archived_at'] != null
        ? DateTime.parse(json['archived_at'] as String) : null,
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'] as String) : null,
  );

  Map<String, dynamic> toJson() => {
    'account_id': accountId,
    'label': label,
    'address': address,
    'lat': lat,
    'lng': lng,
    'state': state,
    'district': district,
    'postcode': postcode,
    'property_type': propertyType,
    'floors': floors,
    'estimated_value': estimatedValue,
    'risk_level': riskLevel,
  };

  /// Short label for a selection dropdown — prefers the user's own label,
  /// then the address, falling back to coordinates when neither is set.
  String get displayLabel {
    final l = label;
    final addr = address;
    if (l != null && l.isNotEmpty) {
      return addr != null && addr.isNotEmpty ? '$l — $addr' : l;
    }
    if (addr != null && addr.isNotEmpty) return addr;
    return propertyType ?? 'Property at ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }
}

/// A saved flood risk assessment for one property.
class FloodSimulation {
  final String? id;
  final String accountId;
  final String propertyName;
  final String structureType;
  final double latitude;
  final double longitude;
  final String state;
  final String district;

  /// User-declared elevation override, if provided; otherwise the
  /// assessment falls back to [terrainElevationMeters].
  final double? userElevationMeters;

  /// Ground elevation at the property's coordinates, from the terrain API.
  final double? terrainElevationMeters;

  /// Ground elevation at the district's centroid — the local baseline the
  /// property's elevation is compared against.
  final double? baselineElevationMeters;

  final bool hasFloodBarriers;
  final bool hasRaisedFoundation;
  final int nearbyFloodCount;

  /// Snapshot of conditions at assessment time — informational only, not
  /// a factor in [riskScore].
  final String? currentWeatherSummary;

  final double riskScore;
  final String riskLevel;
  final DateTime? createdAt;

  FloodSimulation({
    this.id,
    required this.accountId,
    required this.propertyName,
    required this.structureType,
    required this.latitude,
    required this.longitude,
    required this.state,
    required this.district,
    this.userElevationMeters,
    this.terrainElevationMeters,
    this.baselineElevationMeters,
    this.hasFloodBarriers = false,
    this.hasRaisedFoundation = false,
    this.nearbyFloodCount = 0,
    this.currentWeatherSummary,
    required this.riskScore,
    required this.riskLevel,
    this.createdAt,
  });

  factory FloodSimulation.fromJson(Map<String, dynamic> json) {
    return FloodSimulation(
      id: json['id'] as String?,
      accountId: json['account_id'] as String,
      propertyName: json['property_name'] as String,
      structureType: json['structure_type'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      state: json['state'] as String,
      district: json['district'] as String,
      userElevationMeters: (json['user_elevation_meters'] as num?)
          ?.toDouble(),
      terrainElevationMeters: (json['terrain_elevation_meters'] as num?)
          ?.toDouble(),
      baselineElevationMeters: (json['baseline_elevation_meters'] as num?)
          ?.toDouble(),
      hasFloodBarriers: json['has_flood_barriers'] as bool? ?? false,
      hasRaisedFoundation: json['has_raised_foundation'] as bool? ?? false,
      nearbyFloodCount: json['nearby_flood_count'] as int? ?? 0,
      currentWeatherSummary: json['current_weather_summary'] as String?,
      riskScore: (json['risk_score'] as num).toDouble(),
      riskLevel: json['risk_level'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'account_id': accountId,
      'property_name': propertyName,
      'structure_type': structureType,
      'latitude': latitude,
      'longitude': longitude,
      'state': state,
      'district': district,
      'user_elevation_meters': userElevationMeters,
      'terrain_elevation_meters': terrainElevationMeters,
      'baseline_elevation_meters': baselineElevationMeters,
      'has_flood_barriers': hasFloodBarriers,
      'has_raised_foundation': hasRaisedFoundation,
      'nearby_flood_count': nearbyFloodCount,
      'current_weather_summary': currentWeatherSummary,
      'risk_score': riskScore,
      'risk_level': riskLevel,
    };
  }
}

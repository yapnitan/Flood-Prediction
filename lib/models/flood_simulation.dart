import 'river_flood_data.dart';

class FloodSimulation {
  final String? id;
  final String accountId;

  final int? propertyId;

  final String propertyName;
  final String structureType;
  final double latitude;
  final double longitude;
  final String state;
  final String district;
  final double? userElevationMeters;
  final double? terrainElevationMeters;
  final double? baselineElevationMeters;

  final bool hasFloodBarriers;
  final bool hasRaisedFoundation;
  final int nearbyFloodCount;
  final int recentReportCount;
  final RiverFloodLevel riverFloodLevel;
  final String? currentWeatherSummary;

  final double riskScore;
  final String riskLevel;
  final DateTime? createdAt;

  FloodSimulation({
    this.id,
    required this.accountId,
    this.propertyId,
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
    this.recentReportCount = 0,
    this.riverFloodLevel = RiverFloodLevel.unknown,
    this.currentWeatherSummary,
    required this.riskScore,
    required this.riskLevel,
    this.createdAt,
  });

  factory FloodSimulation.fromJson(Map<String, dynamic> json) {
    return FloodSimulation(
      id: json['id'] as String?,
      accountId: json['account_id'] as String,
      propertyId: (json['property_id'] as num?)?.toInt(),
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
      recentReportCount: json['recent_report_count'] as int? ?? 0,
      riverFloodLevel:
          RiverFloodLevelInfo.fromKey(json['river_flood_level'] as String?),
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
      'property_id': propertyId,
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
      'recent_report_count': recentReportCount,
      'river_flood_level': riverFloodLevel.key,
      'current_weather_summary': currentWeatherSummary,
      'risk_score': riskScore,
      'risk_level': riskLevel,
    };
  }
}

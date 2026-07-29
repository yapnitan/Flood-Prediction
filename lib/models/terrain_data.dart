class TerrainData {
  final double latitude;
  final double longitude;
  final double elevationMeters;

  TerrainData({
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
  });

  factory TerrainData.fromJson(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
  }) {
    final elevations = json['elevation'] as List;
    return TerrainData(
      latitude: latitude,
      longitude: longitude,
      elevationMeters: (elevations.first as num).toDouble(),
    );
  }
}

import 'dart:math';

/// Great-circle distance between two coordinates, in kilometres.
double haversineDistanceKm({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) {
  const earthRadiusKm = 6371.0;

  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * pi / 180;

/// Approximate degrees-of-latitude/longitude span for a given radius in km,
/// used to narrow a query with a bounding box before ranking by exact
/// distance (cheap index-friendly filter step).
class GeoBoundingBox {
  final double minLat;
  final double maxLat;
  final double minLon;
  final double maxLon;

  GeoBoundingBox({
    required this.minLat,
    required this.maxLat,
    required this.minLon,
    required this.maxLon,
  });

  factory GeoBoundingBox.fromCenter({
    required double lat,
    required double lon,
    required double radiusKm,
  }) {
    final latDelta = radiusKm / 111.0;
    final lonDelta = radiusKm / (111.0 * cos(_degToRad(lat)).abs().clamp(0.01, 1.0));

    return GeoBoundingBox(
      minLat: lat - latDelta,
      maxLat: lat + latDelta,
      minLon: lon - lonDelta,
      maxLon: lon + lonDelta,
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/utils/geo_utils.dart';

void main() {
  group('haversineDistanceKm', () {
    test('same point is zero distance', () {
      final distance = haversineDistanceKm(lat1: 3.1390, lon1: 101.6869, lat2: 3.1390, lon2: 101.6869);
      expect(distance, closeTo(0, 0.0001));
    });

    test('Kuala Lumpur to Petaling Jaya is roughly 10km', () {
      // KLCC vs. central PJ — real-world distance is ~9-10km.
      final distance = haversineDistanceKm(
        lat1: 3.1579,
        lon1: 101.7116,
        lat2: 3.1073,
        lon2: 101.6067,
      );
      expect(distance, greaterThan(8));
      expect(distance, lessThan(13));
    });

    test('is symmetric regardless of point order', () {
      final a = haversineDistanceKm(lat1: 3.1390, lon1: 101.6869, lat2: 5.4141, lon2: 100.3288);
      final b = haversineDistanceKm(lat1: 5.4141, lon1: 100.3288, lat2: 3.1390, lon2: 101.6869);
      expect(a, closeTo(b, 0.0001));
    });
  });

  group('GeoBoundingBox.fromCenter', () {
    test('center point falls within its own bounding box', () {
      final box = GeoBoundingBox.fromCenter(lat: 3.1390, lon: 101.6869, radiusKm: 20);
      expect(box.minLat, lessThan(3.1390));
      expect(box.maxLat, greaterThan(3.1390));
      expect(box.minLon, lessThan(101.6869));
      expect(box.maxLon, greaterThan(101.6869));
    });

    test('a larger radius produces a wider box', () {
      final small = GeoBoundingBox.fromCenter(lat: 3.1390, lon: 101.6869, radiusKm: 5);
      final large = GeoBoundingBox.fromCenter(lat: 3.1390, lon: 101.6869, radiusKm: 50);
      expect(large.maxLat - large.minLat, greaterThan(small.maxLat - small.minLat));
    });
  });
}

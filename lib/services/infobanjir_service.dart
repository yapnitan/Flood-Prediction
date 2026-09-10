import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/infobanjir_station.dart';
import '../utils/geo_utils.dart';
import '../utils/http_retry.dart';

class InfoBanjirService {
  static const _feedUrl =
      'https://publicinfobanjir.water.gov.my/wp-content/themes/enlighten/data/latestreadingstrendabc.json';

  static const _cacheTtl = Duration(minutes: 10);

  static List<InfoBanjirStation>? _cache;
  static DateTime? _cachedAt;

  Future<List<InfoBanjirStation>> _stations() async {
    final cached = _cache;
    if (cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return cached;
    }

    try {
      final response = await getWithRetry(
        Uri.parse(_feedUrl),
        timeout: const Duration(seconds: 15),
      );
      if (response.statusCode != 200) {
        debugPrint('InfoBanjirService HTTP ${response.statusCode}');
        return cached ?? const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return cached ?? const [];

      final stations = decoded
          .whereType<Map<String, dynamic>>()
          .map(InfoBanjirStation.fromJson)
          .where((s) => s.hasCoordinates)
          .toList();

      _cache = stations;
      _cachedAt = DateTime.now();
      return stations;
    } catch (error) {
      debugPrint('InfoBanjirService.load error: $error');
      return cached ?? const [];
    }
  }

  Future<InfoBanjirStation?> getNearestRainfallStation({
    required double latitude,
    required double longitude,
    double maxRadiusKm = 30,
  }) {
    return _nearest(
      latitude: latitude,
      longitude: longitude,
      maxRadiusKm: maxRadiusKm,
      usable: (s) => s.hasFreshRainfall(),
    );
  }

  Future<InfoBanjirStation?> getNearestRiverLevelStation({
    required double latitude,
    required double longitude,
    double maxRadiusKm = 15,
  }) {
    return _nearest(
      latitude: latitude,
      longitude: longitude,
      maxRadiusKm: maxRadiusKm,
      usable: (s) => s.hasFreshWaterLevel(),
    );
  }

  Future<InfoBanjirStation?> _nearest({
    required double latitude,
    required double longitude,
    required double maxRadiusKm,
    required bool Function(InfoBanjirStation) usable,
  }) async {
    final stations = await _stations();

    InfoBanjirStation? nearest;
    double? nearestDistanceKm;
    for (final station in stations) {
      if (!usable(station)) continue;
      final distanceKm = haversineDistanceKm(
        lat1: latitude,
        lon1: longitude,
        lat2: station.latitude,
        lon2: station.longitude,
      );
      if (distanceKm > maxRadiusKm) continue;
      if (nearestDistanceKm == null || distanceKm < nearestDistanceKm) {
        nearest = station;
        nearestDistanceKm = distanceKm;
      }
    }
    return nearest;
  }
}

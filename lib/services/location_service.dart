import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../utils/malaysia_geocoding.dart';

class GeocodeResult {
  const GeocodeResult({this.address, this.state, this.district, this.postcode});

  final String? address;
  final String? state;
  final String? district;
  final String? postcode;
}

class CurrentLocationDetails {
  const CurrentLocationDetails({
    required this.position,
    this.address,
    this.state,
    this.district,
    this.postcode,
  });

  final Position position;
  final String? address;
  final String? state;
  final String? district;
  final String? postcode;
}

class PlaceSearchResult {
  const PlaceSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    this.state,
    this.district,
    this.postcode,
  });

  final String displayName;
  final double latitude;
  final double longitude;
  final String? state;
  final String? district;
  final String? postcode;
}

class LocationService {
  static const _timeout = Duration(seconds: 8);

  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled()
          .timeout(_timeout);
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission().timeout(_timeout);
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(_timeout);
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(_timeout);
    } catch (_) {
      return null;
    }
  }

  Future<GeocodeResult?> reverseGeocode(double latitude, double longitude) async {
    try {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
        }),
        headers: const {'User-Agent': 'FloodPrediction/1.0'},
      ).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      if (displayName == null || displayName.trim().isEmpty) return null;

      return _areaFromComponents(displayName, data['address'] as Map<String, dynamic>?);
    } catch (_) {
      return null;
    }
  }

  GeocodeResult _areaFromComponents(String? address, Map<String, dynamic>? components) {
    final isoState = MalaysiaGeocoder.stateFromIsoCode(components?['ISO3166-2-lvl4'] as String?);
    final rawState = components?['state'] as String?;
    final district = (components?['county'] ??
        components?['state_district'] ??
        components?['city_district'] ??
        components?['district'] ??
        components?['suburb']) as String?;

    return GeocodeResult(
      address: address,
      state: isoState ?? (rawState != null ? MalaysiaGeocoder.canonicalStateName(rawState) : null),
      district: district,
      postcode: components?['postcode'] as String?,
    );
  }

  Future<List<PlaceSearchResult>> searchPlaces(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'format': 'jsonv2',
        'q': trimmed,
        'countrycodes': 'my',
        'addressdetails': '1',
        'limit': '$limit',
      });
      final response = await http.get(
        uri,
        headers: const {'User-Agent': 'FloodPrediction/1.0'},
      ).timeout(_timeout);
      if (response.statusCode != 200) {
        debugPrint('LocationService.searchPlaces "$trimmed" HTTP ${response.statusCode}');
        return const [];
      }

      final data = jsonDecode(response.body) as List<dynamic>;
      final results = <PlaceSearchResult>[];
      for (final entry in data) {
        if (entry is! Map<String, dynamic>) continue;
        final displayName = entry['display_name'] as String?;
        final lat = double.tryParse('${entry['lat']}');
        final lon = double.tryParse('${entry['lon']}');
        if (displayName == null || lat == null || lon == null) continue;

        final area = _areaFromComponents(
          displayName,
          entry['address'] as Map<String, dynamic>?,
        );
        results.add(PlaceSearchResult(
          displayName: displayName,
          latitude: lat,
          longitude: lon,
          state: area.state,
          district: area.district,
          postcode: area.postcode,
        ));
      }
      return results;
    } catch (_) {
      return const [];
    }
  }

  Future<CurrentLocationDetails?> getCurrentLocationDetails() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    final geocode = await reverseGeocode(position.latitude, position.longitude);

    return CurrentLocationDetails(
      position: position,
      address: geocode?.address,
      state: geocode?.state,
      district: geocode?.district,
      postcode: geocode?.postcode,
    );
  }
}

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class CurrentLocationDetails {
  const CurrentLocationDetails({required this.position, this.address});

  final Position position;
  final String? address;
}

/// Wraps device GPS access: checks/requests permission, then reads position.
class LocationService {
  static const _timeout = Duration(seconds: 8);

  /// Never hangs indefinitely — returns null if location services/permission
  /// are unavailable, denied, or acquisition takes longer than [_timeout].
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

  Future<CurrentLocationDetails?> getCurrentLocationDetails() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    try {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/reverse', {
          'format': 'jsonv2',
          'lat': position.latitude.toString(),
          'lon': position.longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
        }),
        headers: const {'User-Agent': 'FloodPrediction/1.0'},
      ).timeout(_timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final displayName = data['display_name'] as String?;
        if (displayName != null && displayName.trim().isNotEmpty) {
          return CurrentLocationDetails(
            position: position,
            address: displayName,
          );
        }
      }
    } catch (_) {
      // GPS is still useful when reverse geocoding is unavailable.
    }

    return CurrentLocationDetails(position: position);
  }
}

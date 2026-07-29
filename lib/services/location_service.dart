import 'package:geolocator/geolocator.dart';

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
}

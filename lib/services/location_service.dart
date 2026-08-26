import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

import '../utils/malaysia_geocoding.dart';

/// Structured reverse-geocode result — the display address plus (when
/// Nominatim's response includes them) the Malaysian state/district/
/// postcode, so callers don't have to derive those by matching keywords
/// against the flat address string.
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

  /// Reverse-geocodes a coordinate via Nominatim, returning both the flat
  /// display address and (best-effort) the structured Malaysian state/
  /// district/postcode from its `address` object — used for both "Use
  /// Current Location" and picking a location from the nearby-locations
  /// autocomplete, so either path can auto-fill an address form's
  /// state/district/postcode instead of requiring manual entry.
  ///
  /// District is unreliable across Nominatim's OSM admin-level tagging for
  /// Malaysia — it can land under `county`, `state_district`, or
  /// `city_district` depending on the area — so all three are tried in
  /// that order. Returns null on any network/parse failure; never throws.
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

      final components = data['address'] as Map<String, dynamic>?;
      // Prefer the ISO 3166-2 code: Nominatim omits the free-text `state`
      // field entirely for the three Federal Territories (Kuala Lumpur/
      // Labuan/Putrajaya — confirmed by direct testing), but the ISO code
      // is present regardless and maps 1:1 to a state/territory.
      final isoState = MalaysiaGeocoder.stateFromIsoCode(components?['ISO3166-2-lvl4'] as String?);
      final rawState = components?['state'] as String?;
      // Kuala Lumpur/Labuan/Putrajaya have no formal "district" subdivision
      // at all in Nominatim's data (confirmed by direct testing) — their
      // named areas (e.g. "Wangsa Maju", "Bukit Bintang") show up under
      // `suburb` instead, so it's tried last, only once none of the more
      // official district-level tags are present.
      final district = (components?['county'] ??
          components?['state_district'] ??
          components?['city_district'] ??
          components?['district'] ??
          components?['suburb']) as String?;

      return GeocodeResult(
        address: displayName,
        state: isoState ?? (rawState != null ? MalaysiaGeocoder.canonicalStateName(rawState) : null),
        district: district,
        postcode: components?['postcode'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  Future<CurrentLocationDetails?> getCurrentLocationDetails() async {
    final position = await getCurrentPosition();
    if (position == null) return null;

    // Reverse geocoding is best-effort — GPS is still useful on its own
    // when it's unavailable (offline, rate-limited, etc.).
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

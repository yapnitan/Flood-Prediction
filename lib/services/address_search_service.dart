import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AddressSearchResult {
  const AddressSearchResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  final String displayName;
  final double latitude;
  final double longitude;
}

class AddressSearchService {
  static const _timeout = Duration(seconds: 8);

  Future<List<AddressSearchResult>> search(String query, {int limit = 8}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    try {
      final response = await http.get(
        Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': trimmed,
          'format': 'jsonv2',
          'addressdetails': '1',
          'countrycodes': 'my',
          'limit': '$limit',
        }),
        headers: const {'User-Agent': 'FloodPrediction/1.0'},
      ).timeout(_timeout);

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as List;
      return data
          .map((row) {
            final map = row as Map<String, dynamic>;
            final lat = double.tryParse(map['lat'] as String? ?? '');
            final lon = double.tryParse(map['lon'] as String? ?? '');
            final name = map['display_name'] as String?;
            if (lat == null || lon == null || name == null) return null;
            return AddressSearchResult(displayName: name, latitude: lat, longitude: lon);
          })
          .whereType<AddressSearchResult>()
          .toList();
    } catch (error) {
      debugPrint('AddressSearchService.search error: $error');
      return [];
    }
  }
}

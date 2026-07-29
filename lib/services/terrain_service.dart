import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/terrain_data.dart';

/// Terrain elevation lookups via the Open-Meteo Elevation API
/// (https://open-meteo.com/en/docs/elevation-api) — free, keyless.
class TerrainService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/elevation';

  Future<TerrainData?> getElevation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('TerrainService.getElevation HTTP ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return TerrainData.fromJson(
        body,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      debugPrint('TerrainService.getElevation error: $e');
      return null;
    }
  }
}

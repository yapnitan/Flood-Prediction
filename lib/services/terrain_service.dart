import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/terrain_data.dart';
import '../utils/http_retry.dart';

class TerrainService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/elevation';

  static const Duration _timeout = Duration(seconds: 8);

  Future<TerrainData?> getElevation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude',
      );

      final response = await getWithRetry(uri, timeout: _timeout);

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

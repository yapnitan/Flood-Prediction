import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/weather_data.dart';
import '../utils/http_retry.dart';

/// Current weather/rainfall/temperature/humidity via the Open-Meteo
/// Forecast API (https://open-meteo.com/en/docs) — free, keyless.
class WeatherService {
  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Cap each call so one slow/hung Open-Meteo response can't stall a whole
  /// risk assessment — a timeout just degrades this factor to "unavailable".
  static const Duration _timeout = Duration(seconds: 8);

  Future<WeatherData?> getCurrentWeather({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&current=temperature_2m,relative_humidity_2m,precipitation,weather_code'
        '&timezone=auto',
      );

      final response = await getWithRetry(uri, timeout: _timeout);

      if (response.statusCode != 200) {
        debugPrint(
          'WeatherService.getCurrentWeather HTTP ${response.statusCode}',
        );
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return WeatherData.fromJson(
        body,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      debugPrint('WeatherService.getCurrentWeather error: $e');
      return null;
    }
  }
}

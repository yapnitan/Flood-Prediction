import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/river_flood_data.dart';
import '../utils/http_retry.dart';

/// Live river-flood signal via the Open-Meteo Flood API
/// (https://open-meteo.com/en/docs/flood-api) — free, keyless. Backed by
/// GloFAS river-discharge modelling: we pull the past 7 days + next 7 days
/// of daily discharge and compare the forecast peak to the recent average.
class RiverFloodService {
  static const String _baseUrl = 'https://flood-api.open-meteo.com/v1/flood';

  /// The GloFAS flood endpoint is the slowest of the Open-Meteo APIs — cap
  /// it so it can't hold up a whole risk assessment on its own.
  static const Duration _timeout = Duration(seconds: 10);

  Future<RiverFloodData?> getRiverFlood({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl?latitude=$latitude&longitude=$longitude'
        '&daily=river_discharge&past_days=7&forecast_days=7',
      );

      final response = await getWithRetry(uri, timeout: _timeout);
      if (response.statusCode != 200) {
        debugPrint('RiverFloodService.getRiverFlood HTTP ${response.statusCode}');
        return null;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final daily = body['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final times = (daily['time'] as List?)?.cast<String>() ?? const [];
      final values = (daily['river_discharge'] as List?) ?? const [];
      if (times.isEmpty || values.length != times.length) return null;

      final now = DateTime.now();
      final todayKey =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      var splitIndex = times.indexOf(todayKey);
      if (splitIndex < 0) splitIndex = math.min(7, times.length); // past_days=7

      final past = <double>[];
      double? currentDischarge;
      double? forecastMax;
      DateTime? peakDate;

      for (var i = 0; i < values.length; i++) {
        final raw = values[i];
        if (raw is! num) continue;
        final value = raw.toDouble();
        if (i < splitIndex) {
          past.add(value);
        } else {
          if (i == splitIndex) currentDischarge = value;
          if (forecastMax == null || value > forecastMax) {
            forecastMax = value;
            peakDate = DateTime.tryParse(times[i]);
          }
        }
      }

      final recentMean =
          past.isEmpty ? null : past.reduce((a, b) => a + b) / past.length;
      if (recentMean == null && forecastMax == null) return null;

      return RiverFloodData(
        currentDischarge: currentDischarge,
        recentMean: recentMean,
        forecastMax: forecastMax,
        forecastPeakDate: peakDate,
      );
    } catch (error) {
      debugPrint('RiverFloodService.getRiverFlood error: $error');
      return null;
    }
  }
}

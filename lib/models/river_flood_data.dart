/// How the nearby river's forecast flow compares to its recent average —
/// derived from GloFAS river-discharge data (Open-Meteo Flood API). This is
/// a live/forecast signal for "is the river rising", not a property's
/// persistent risk profile.
enum RiverFloodLevel { unknown, low, normal, elevated, high }

extension RiverFloodLevelInfo on RiverFloodLevel {
  String get key => name;

  static RiverFloodLevel fromKey(String? key) => RiverFloodLevel.values.firstWhere(
        (level) => level.name == key,
        orElse: () => RiverFloodLevel.unknown,
      );

  /// One-line description for the simulation detail screen. `null` for
  /// [RiverFloodLevel.unknown] — there's no modelled river to talk about.
  String? get description {
    switch (this) {
      case RiverFloodLevel.unknown:
        return null;
      case RiverFloodLevel.low:
        return 'Nearby river flow is forecast below its recent average — low river flood risk.';
      case RiverFloodLevel.normal:
        return 'Nearby river flow is forecast near its recent average — normal river conditions.';
      case RiverFloodLevel.elevated:
        return 'Nearby river flow is forecast to rise above its recent average — '
            'elevated river flood risk over the coming days.';
      case RiverFloodLevel.high:
        return 'Nearby river flow is forecast to surge well above its recent average — '
            'high river flood risk over the coming days.';
    }
  }
}

/// Parsed GloFAS river-discharge window for a coordinate: the recent
/// baseline vs. the forecast peak. [level] buckets the ratio between them.
class RiverFloodData {
  const RiverFloodData({
    this.currentDischarge,
    this.recentMean,
    this.forecastMax,
    this.forecastPeakDate,
  });

  /// m³/s at the coordinate's river reach for today.
  final double? currentDischarge;

  /// Mean m³/s over the past ~7 days — the baseline the forecast is compared to.
  final double? recentMean;

  /// Highest forecast m³/s over the next ~7 days.
  final double? forecastMax;
  final DateTime? forecastPeakDate;

  /// forecastMax / recentMean, or null when either is missing / the river
  /// isn't modelled here (GloFAS only covers rivers above a catchment size).
  double? get riseRatio {
    final base = recentMean;
    final peak = forecastMax;
    if (base == null || peak == null || base <= 0) return null;
    return peak / base;
  }

  RiverFloodLevel get level {
    final ratio = riseRatio;
    if (ratio == null) return RiverFloodLevel.unknown;
    if (ratio < 0.8) return RiverFloodLevel.low;
    if (ratio < 1.3) return RiverFloodLevel.normal;
    if (ratio < 2.0) return RiverFloodLevel.elevated;
    return RiverFloodLevel.high;
  }
}

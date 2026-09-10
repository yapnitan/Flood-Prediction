
enum RiverFloodLevel { unknown, low, normal, elevated, high }

extension RiverFloodLevelInfo on RiverFloodLevel {
  String get key => name;

  static RiverFloodLevel fromKey(String? key) => RiverFloodLevel.values.firstWhere(
        (level) => level.name == key,
        orElse: () => RiverFloodLevel.unknown,
      );
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

class RiverFloodData {
  const RiverFloodData({
    this.currentDischarge,
    this.recentMean,
    this.forecastMax,
    this.forecastPeakDate,
  });

  final double? currentDischarge;

  final double? recentMean;

  final double? forecastMax;
  final DateTime? forecastPeakDate;

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

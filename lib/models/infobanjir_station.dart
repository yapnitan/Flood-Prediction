/// One JPS/DID Public InfoBanjir telemetry station and its latest readings.
/// Source: the public "latest readings" feed at publicinfobanjir.water.gov.my
/// — the same data behind the InfoBanjir map. A station may report rainfall,
/// river water level, or both.
///
/// The feed uses single-letter keys and `-9999` / blank / negative values as
/// "no data" sentinels, so parsing is defensive.
class InfoBanjirStation {
  const InfoBanjirStation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.district,
    this.state,
    this.measuresRainfall = false,
    this.rainfall1hMm,
    this.rainfall3hMm,
    this.rainfallTodayMm,
    this.rainfallIntensity,
    this.rainfallUpdatedAt,
    this.measuresWaterLevel = false,
    this.waterLevelM,
    this.normalLevelM,
    this.metresAboveNormal,
    this.waterLevelStatus,
    this.waterLevelTrend,
    this.waterLevelUpdatedAt,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? district;
  final String? state;

  // ---- Rainfall ----
  final bool measuresRainfall;
  final double? rainfall1hMm;
  final double? rainfall3hMm;
  final double? rainfallTodayMm;

  /// The feed's own label: "No Rainfall" / "Light" / "Moderate" / "Heavy" /
  /// "Very Heavy" (or "Error"/blank when the sensor is down).
  final String? rainfallIntensity;
  final DateTime? rainfallUpdatedAt;

  // ---- River water level ----
  final bool measuresWaterLevel;
  final double? waterLevelM;
  final double? normalLevelM;
  final double? metresAboveNormal;

  /// The feed's official status: "Normal" / "Alert" / "Warning" / "Danger"
  /// (or "Error"/blank when the sensor is down).
  final String? waterLevelStatus;

  /// "Rising" / "Receding" / "No Change".
  final String? waterLevelTrend;
  final DateTime? waterLevelUpdatedAt;

  bool get isRising => waterLevelTrend == 'Rising';

  /// A rainfall station with a usable, non-stale 1-hour reading.
  bool hasFreshRainfall({Duration maxAge = const Duration(hours: 3)}) {
    if (!measuresRainfall ||
        rainfall1hMm == null ||
        rainfallUpdatedAt == null) {
      return false;
    }
    return DateTime.now().toUtc().difference(rainfallUpdatedAt!) <= maxAge;
  }

  /// A river gauge with a usable, non-stale level reading and a real status.
  bool hasFreshWaterLevel({Duration maxAge = const Duration(hours: 3)}) {
    final status = waterLevelStatus;
    if (!measuresWaterLevel ||
        waterLevelM == null ||
        waterLevelUpdatedAt == null ||
        status == null ||
        status.toLowerCase() == 'error') {
      return false;
    }
    return DateTime.now().toUtc().difference(waterLevelUpdatedAt!) <= maxAge;
  }

  factory InfoBanjirStation.fromJson(Map<String, dynamic> json) {
    final type = (json['i'] as String?) ?? '';
    return InfoBanjirStation(
      id: (json['a'] as String?)?.trim() ?? '',
      name: (json['b'] as String?)?.trim() ?? 'Unknown station',
      latitude: _double(json['c']) ?? 0,
      longitude: _double(json['d']) ?? 0,
      district: _text(json['e']),
      state: _text(json['f']),
      measuresRainfall: type.contains('RF'),
      rainfall1hMm: _reading(json['u']),
      rainfall3hMm: _reading(json['v']),
      rainfallTodayMm: _reading(json['w']),
      rainfallIntensity: _text(json['x']),
      rainfallUpdatedAt: _dateTime(json['y']),
      measuresWaterLevel: type.contains('WL'),
      waterLevelM: _reading(json['m']),
      normalLevelM: _reading(json['o']),
      metresAboveNormal: _double(json['p']),
      waterLevelStatus: _text(json['n']),
      waterLevelTrend: _text(json['s']),
      waterLevelUpdatedAt: _dateTime(json['q']),
    );
  }

  bool get hasCoordinates =>
      latitude.abs() > 0.01 &&
      longitude.abs() > 0.01 &&
      latitude > -12 &&
      latitude < 12 &&
      longitude > 90 &&
      longitude < 125;

  static String? _text(Object? v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static double? _double(Object? v) => double.tryParse(v?.toString().trim() ?? '');

  /// A measurement value, or null for the feed's sentinels
  /// (`-9999`, `-10004`, blank, or any negative).
  static double? _reading(Object? v) {
    final d = _double(v);
    if (d == null || d < 0) return null;
    return d;
  }

  /// Feed timestamps are `dd/MM/yyyy HH:mm` in Malaysian time (UTC+8);
  /// returned as a UTC instant so staleness checks work on any device clock.
  static DateTime? _dateTime(Object? v) {
    final s = v?.toString().trim();
    if (s == null || s.isEmpty) return null;
    final match = RegExp(
      r'^(\d{2})/(\d{2})/(\d{4})\s+(\d{1,2}):(\d{2})',
    ).firstMatch(s);
    if (match == null) return null;
    return DateTime.utc(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    ).subtract(const Duration(hours: 8));
  }
}

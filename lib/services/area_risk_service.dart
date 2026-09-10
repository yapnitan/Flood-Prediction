import '../models/river_flood_data.dart';
import '../models/simulation_factor.dart';

class AreaRiskInput {
  final int nearbyHistoricalFloodCount;

  /// Rainfall over the last hour (mm) — from the nearest InfoBanjir gauge, or
  /// the Open-Meteo forecast model as a fallback.
  final double? currentRainfallMm;

  /// JPS/DID InfoBanjir's own intensity label for that gauge, if it's from a
  /// gauge: "No Rainfall" / "Light" / "Moderate" / "Heavy" / "Very Heavy".
  /// Scored directly (the government's own classification) when present.
  final String? rainfallIntensityLabel;

  final List<String> nearbyReportWaterLevels;

  /// Nearest JPS/DID InfoBanjir river gauge status, if one is in range:
  /// "Normal" / "Alert" / "Warning" / "Danger". Takes priority over
  /// [riverFloodLevel] (the GloFAS forecast fallback).
  final String? riverGaugeStatus;

  /// Whether that gauge's level is rising.
  final bool riverGaugeRising;

  /// GloFAS forecast level (Open-Meteo Flood API) — only used when no
  /// InfoBanjir gauge is in range.
  final RiverFloodLevel riverFloodLevel;

  AreaRiskInput({
    required this.nearbyHistoricalFloodCount,
    required this.currentRainfallMm,
    required this.nearbyReportWaterLevels,
    this.rainfallIntensityLabel,
    this.riverGaugeStatus,
    this.riverGaugeRising = false,
    this.riverFloodLevel = RiverFloodLevel.unknown,
  });
}

class AreaRiskResult {
  final double score;
  final String level;
  final List<SimulationFactor> factors;

  AreaRiskResult({
    required this.score,
    required this.level,
    required this.factors,
  });
}

/// Pure scoring engine for the Home tab's ambient "flood status" badge.
/// Unlike [RiskAssessmentService], this isn't scoped to a saved property
/// (no elevation/structure/barrier data), so it answers a different
/// question — "what's the flood situation right here, right now?" —
/// recomputed on demand rather than saved to `flood_simulation`.
///
/// Score (0-100). The four factor caps add up to exactly 100:
///   - Historical flood frequency nearby — +5 each, capped 25
///   - Rainfall over the last hour — Light 10 / Moderate 18 / Heavy 25,
///     matching JPS/DID's own intensity bands
///   - Nearby community flood reports — Low 10 / Medium 15 / High 20 each,
///     capped 30
///   - Nearby river level — InfoBanjir gauge status (Danger 20 / Warning 15 /
///     Alert 8 / rising 3), or the GloFAS forecast (elevated 8 / high 15)
class AreaRiskService {
  static const Map<String, double> _reportSeverityPoints = {
    'Low': 10,
    'Medium': 15,
    'High': 20,
  };

  AreaRiskResult assess(AreaRiskInput input) {
    final factors = <SimulationFactor>[];

    // Long-term hazard baseline: historical flood frequency (0-25 points).
    final historyPoints = (input.nearbyHistoricalFloodCount * 5)
        .clamp(0, 25)
        .toDouble();
    factors.add(
      SimulationFactor(
        factorName: 'Historical flood frequency (20km)',
        factorValue: input.nearbyHistoricalFloodCount == 0
            ? 'No recorded floods nearby in the JPS/DID dataset'
            : '${input.nearbyHistoricalFloodCount} recorded flood(s) nearby',
        scoreContribution: historyPoints,
      ),
    );

    // Live signal: rainfall over the last hour (0-25 points), banded to match
    // JPS/DID's own intensity classification for hourly totals:
    //   Light ≤10 mm → 10, Moderate 10-30 → 18, Heavy/Very Heavy ≥30 → 25.
    // Uses the gauge's own label when available, else the mm value.
    final rainfallMm = input.currentRainfallMm;
    final label = input.rainfallIntensityLabel?.trim().toLowerCase();
    final mmText = rainfallMm == null
        ? ''
        : ' (${rainfallMm.toStringAsFixed(1)}mm in the last hour)';
    double rainfallPoints = 0;
    String rainfallDescription = 'Rainfall data unavailable';

    if (label != null && label.isNotEmpty && label != 'error') {
      switch (label) {
        case 'very heavy':
        case 'heavy':
          rainfallPoints = 25;
          rainfallDescription = 'Heavy rain nearby$mmText';
        case 'moderate':
          rainfallPoints = 18;
          rainfallDescription = 'Moderate rain nearby$mmText';
        case 'light':
          rainfallPoints = 10;
          rainfallDescription = 'Light rain nearby$mmText';
        default: // 'no rainfall'
          rainfallPoints = 0;
          rainfallDescription = 'No rain in the last hour';
      }
    } else if (rainfallMm != null) {
      if (rainfallMm >= 30) {
        rainfallPoints = 25;
        rainfallDescription = 'Heavy rain nearby$mmText';
      } else if (rainfallMm >= 10) {
        rainfallPoints = 18;
        rainfallDescription = 'Moderate rain nearby$mmText';
      } else if (rainfallMm >= 2) {
        rainfallPoints = 10;
        rainfallDescription = 'Light rain nearby$mmText';
      } else {
        rainfallPoints = 0;
        rainfallDescription = rainfallMm > 0
            ? 'Trace rainfall$mmText'
            : 'No rain in the last hour';
      }
    }
    factors.add(
      SimulationFactor(
        factorName: 'Current rainfall',
        factorValue: rainfallDescription,
        scoreContribution: rainfallPoints,
      ),
    );

    // Live signal: community flood reports nearby (0-30 points) — the
    // strongest signal, since it's a direct eyewitness account rather than
    // an inference from weather or history.
    final reportPoints = input.nearbyReportWaterLevels
        .fold<double>(
          0,
          (sum, level) => sum + (_reportSeverityPoints[level] ?? 10),
        )
        .clamp(0, 30)
        .toDouble();
    factors.add(
      SimulationFactor(
        factorName: 'Community reports nearby (5km, 24h)',
        factorValue: input.nearbyReportWaterLevels.isEmpty
            ? 'No recent community reports nearby'
            : '${input.nearbyReportWaterLevels.length} recent report(s) nearby',
        scoreContribution: reportPoints,
      ),
    );

    // Live signal: nearby river level (0-20 points). Primary source is the
    // nearest JPS/DID InfoBanjir river gauge and its official status; the
    // GloFAS forecast (Open-Meteo) is only used when no gauge is in range.
    double riverPoints = 0;
    String riverDescription;
    final gaugeStatus = input.riverGaugeStatus;
    if (gaugeStatus != null) {
      switch (gaugeStatus.toLowerCase()) {
        case 'danger':
          riverPoints = 20;
          riverDescription = 'Nearby river gauge at DANGER level';
        case 'warning':
          riverPoints = 15;
          riverDescription = 'Nearby river gauge at WARNING level';
        case 'alert':
          riverPoints = 8;
          riverDescription = 'Nearby river gauge at ALERT level';
        default:
          riverPoints = input.riverGaugeRising ? 3 : 0;
          riverDescription = input.riverGaugeRising
              ? 'Nearby river gauge normal, but rising'
              : 'Nearby river gauge at a normal level';
      }
    } else {
      switch (input.riverFloodLevel) {
        case RiverFloodLevel.high:
          riverPoints = 15;
          riverDescription =
              'Nearby river forecast to surge well above its recent average';
        case RiverFloodLevel.elevated:
          riverPoints = 8;
          riverDescription =
              'Nearby river forecast to rise above its recent average';
        case RiverFloodLevel.low:
          riverDescription =
              'Nearby river flow forecast below its recent average';
        case RiverFloodLevel.normal:
          riverDescription =
              'Nearby river flow forecast near its recent average';
        case RiverFloodLevel.unknown:
          riverDescription = 'No river gauge or modelled river near this location';
      }
    }
    factors.add(
      SimulationFactor(
        factorName: 'Nearby river level',
        factorValue: riverDescription,
        scoreContribution: riverPoints,
      ),
    );

    final rawScore = factors.fold<double>(
      0,
      (sum, f) => sum + f.scoreContribution,
    );
    final score = rawScore.clamp(0, 100).toDouble();
    final level = score >= 67 ? 'High' : (score >= 34 ? 'Medium' : 'Low');

    return AreaRiskResult(score: score, level: level, factors: factors);
  }
}

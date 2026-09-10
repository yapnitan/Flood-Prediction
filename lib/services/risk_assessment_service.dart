import '../models/river_flood_data.dart';
import '../models/simulation_factor.dart';

class RiskAssessmentInput {
  final int nearbyFloodCount;

  /// Water levels ("Low" / "Medium" / "High") of community flood reports
  /// submitted nearby in the last 7 days — a live signal that flooding is
  /// happening now, distinct from the historical [nearbyFloodCount]. Scored
  /// by severity, the same way the Home tab does.
  final List<String> recentReportWaterLevels;

  /// Rainfall over the last hour (mm) — from the nearest JPS/DID InfoBanjir
  /// rain gauge, or the Open-Meteo forecast model as a fallback.
  final double? rainfallMm;

  /// InfoBanjir's own intensity label for that gauge, if it's from a gauge.
  final String? rainfallIntensityLabel;

  /// Nearest InfoBanjir river gauge status ("Normal" / "Alert" / "Warning" /
  /// "Danger"), if one is in range — takes priority over [riverFloodLevel].
  final String? riverGaugeStatus;
  final bool riverGaugeRising;

  /// GloFAS forecast level (Open-Meteo Flood API) — the fallback when no
  /// InfoBanjir river gauge is in range.
  final RiverFloodLevel riverFloodLevel;

  final double? propertyElevationMeters;
  final double? baselineElevationMeters;
  final String structureType;
  final bool hasFloodBarriers;
  final bool hasRaisedFoundation;

  RiskAssessmentInput({
    required this.nearbyFloodCount,
    this.recentReportWaterLevels = const [],
    this.rainfallMm,
    this.rainfallIntensityLabel,
    this.riverGaugeStatus,
    this.riverGaugeRising = false,
    this.riverFloodLevel = RiverFloodLevel.unknown,
    required this.propertyElevationMeters,
    required this.baselineElevationMeters,
    required this.structureType,
    required this.hasFloodBarriers,
    required this.hasRaisedFoundation,
  });
}

class RiskAssessmentResult {
  final double score;
  final String level;
  final List<SimulationFactor> factors;
  final List<String> recommendations;

  RiskAssessmentResult({
    required this.score,
    required this.level,
    required this.factors,
    required this.recommendations,
  });
}

/// Pure risk-scoring engine — no Supabase/network I/O, just arithmetic over
/// already-gathered inputs. [RiskAssessmentController] fetches those inputs
/// (historical records, community reports, InfoBanjir gauges, terrain) first.
///
/// The six hazard/vulnerability factor caps add up to exactly 100:
///   - Historical flood frequency nearby — +5 each, capped 25 (JPS/DID)
///   - Recent community flood reports — Low 10 / Medium 15 / High 20 each,
///     capped 20 (same weighting as the Home tab)
///   - Rainfall over the last hour — Light 4 / Moderate 7 / Heavy 10, on
///     JPS's own intensity bands (InfoBanjir gauge, Open-Meteo fallback)
///   - Nearby river level — InfoBanjir gauge status (Danger 15 / Warning 11 /
///     Alert 6 / rising 2), or the GloFAS forecast (elevated 6 / high 11)
///   - Property elevation relative to its district's baseline — capped 20
///   - Structure type (vulnerability) — 3 to 10
/// Flood barriers and a raised foundation each subtract 10 (mitigation), so
/// the final score is `(hazards + vulnerability - mitigation)` clamped 0-100.
class RiskAssessmentService {
  static const Map<String, double> structureVulnerability = {
    'Single-storey house': 10,
    'Multi-storey house': 6,
    'Apartment / Condominium': 3,
    'Shophouse / Commercial': 8,
    'Other': 6,
  };

  static const Map<String, double> _reportSeverityPoints = {
    'Low': 10,
    'Medium': 15,
    'High': 20,
  };

  static List<String> get structureTypeOptions =>
      structureVulnerability.keys.toList();

  RiskAssessmentResult assess(RiskAssessmentInput input) {
    final factors = <SimulationFactor>[];

    // Hazard: historical flood frequency nearby (0-25 points, +5 each).
    final historyPoints = (input.nearbyFloodCount * 5).clamp(0, 25).toDouble();
    factors.add(
      SimulationFactor(
        factorName: 'Historical flood frequency',
        factorValue: input.nearbyFloodCount == 0
            ? 'No recorded floods nearby in the JPS/DID dataset'
            : '${input.nearbyFloodCount} recorded flood(s) nearby',
        scoreContribution: historyPoints,
      ),
    );

    // Hazard: recent nearby community flood reports (0-20 points), scored by
    // severity the same way the Home tab does.
    final reportPoints = input.recentReportWaterLevels
        .fold<double>(
          0,
          (sum, level) => sum + (_reportSeverityPoints[level] ?? 10),
        )
        .clamp(0, 20)
        .toDouble();
    factors.add(
      SimulationFactor(
        factorName: 'Recent community flood reports',
        factorValue: input.recentReportWaterLevels.isEmpty
            ? 'No community flood reports nearby in the last 7 days'
            : '${input.recentReportWaterLevels.length} community flood report(s) '
                  'nearby in the last 7 days',
        scoreContribution: reportPoints,
      ),
    );

    // Hazard: rainfall over the last hour (0-10 points), on JPS's own bands.
    final rainfallMm = input.rainfallMm;
    final rainLabel = input.rainfallIntensityLabel?.trim().toLowerCase();
    final mmText = rainfallMm == null
        ? ''
        : ' (${rainfallMm.toStringAsFixed(1)}mm in the last hour)';
    double rainfallPoints = 0;
    String rainfallDescription = 'Rainfall data unavailable';
    if (rainLabel != null && rainLabel.isNotEmpty && rainLabel != 'error') {
      switch (rainLabel) {
        case 'very heavy':
        case 'heavy':
          rainfallPoints = 10;
          rainfallDescription = 'Heavy rain nearby$mmText';
        case 'moderate':
          rainfallPoints = 7;
          rainfallDescription = 'Moderate rain nearby$mmText';
        case 'light':
          rainfallPoints = 4;
          rainfallDescription = 'Light rain nearby$mmText';
        default:
          rainfallDescription = 'No rain in the last hour';
      }
    } else if (rainfallMm != null) {
      if (rainfallMm >= 30) {
        rainfallPoints = 10;
        rainfallDescription = 'Heavy rain nearby$mmText';
      } else if (rainfallMm >= 10) {
        rainfallPoints = 7;
        rainfallDescription = 'Moderate rain nearby$mmText';
      } else if (rainfallMm >= 2) {
        rainfallPoints = 4;
        rainfallDescription = 'Light rain nearby$mmText';
      } else {
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

    // Hazard: nearby river level (0-15 points). InfoBanjir gauge status
    // first, GloFAS forecast as the fallback.
    double riverPoints = 0;
    String riverDescription;
    final gaugeStatus = input.riverGaugeStatus;
    if (gaugeStatus != null) {
      switch (gaugeStatus.toLowerCase()) {
        case 'danger':
          riverPoints = 15;
          riverDescription = 'Nearby river gauge at DANGER level';
        case 'warning':
          riverPoints = 11;
          riverDescription = 'Nearby river gauge at WARNING level';
        case 'alert':
          riverPoints = 6;
          riverDescription = 'Nearby river gauge at ALERT level';
        default:
          riverPoints = input.riverGaugeRising ? 2 : 0;
          riverDescription = input.riverGaugeRising
              ? 'Nearby river gauge normal, but rising'
              : 'Nearby river gauge at a normal level';
      }
    } else {
      switch (input.riverFloodLevel) {
        case RiverFloodLevel.high:
          riverPoints = 11;
          riverDescription =
              'Nearby river forecast to surge well above its recent average';
        case RiverFloodLevel.elevated:
          riverPoints = 6;
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

    // Hazard: elevation relative to the district baseline (0-20 points).
    double elevationPoints = 0;
    String elevationDescription = 'Elevation data unavailable';
    if (input.propertyElevationMeters != null &&
        input.baselineElevationMeters != null) {
      final deficit =
          input.baselineElevationMeters! - input.propertyElevationMeters!;
      elevationPoints = (deficit * 4).clamp(0, 20).toDouble();
      elevationDescription = deficit > 0
          ? 'Property sits ${deficit.toStringAsFixed(1)}m below the surrounding area\'s typical elevation'
          : 'Property sits at or above the surrounding area\'s typical elevation';
    }
    factors.add(
      SimulationFactor(
        factorName: 'Relative elevation',
        factorValue: elevationDescription,
        scoreContribution: elevationPoints,
      ),
    );

    // Vulnerability: structure type (3-10 points).
    final structurePoints = structureVulnerability[input.structureType] ?? 6;
    factors.add(
      SimulationFactor(
        factorName: 'Structure type',
        factorValue: input.structureType,
        scoreContribution: structurePoints,
      ),
    );

    // Mitigation: flood barriers (-10 if present).
    factors.add(
      SimulationFactor(
        factorName: 'Flood barriers',
        factorValue: input.hasFloodBarriers ? 'Present' : 'Not present',
        scoreContribution: input.hasFloodBarriers ? -10 : 0,
      ),
    );

    // Mitigation: raised foundation (-10 if present).
    factors.add(
      SimulationFactor(
        factorName: 'Raised foundation',
        factorValue: input.hasRaisedFoundation ? 'Present' : 'Not present',
        scoreContribution: input.hasRaisedFoundation ? -10 : 0,
      ),
    );

    final rawScore = factors.fold<double>(
      0,
      (sum, f) => sum + f.scoreContribution,
    );
    final score = rawScore.clamp(0, 100).toDouble();

    final level = score >= 67 ? 'High' : (score >= 34 ? 'Medium' : 'Low');

    final riverElevatedOrWorse = riverPoints >= 6;

    final recommendations = <String>[];
    if (!input.hasFloodBarriers) {
      recommendations.add(
        'Install flood barriers or sandbags at entry points to reduce water ingress.',
      );
    }
    if (!input.hasRaisedFoundation && elevationPoints > 0) {
      recommendations.add(
        'Consider raising the foundation or elevating critical utilities above the flood-prone level.',
      );
    }
    if (input.recentReportWaterLevels.isNotEmpty) {
      recommendations.add(
        'Neighbours have reported flooding near here in the last week — treat this as an '
        'active-risk area, keep an evacuation plan ready, and follow local updates.',
      );
    }
    if (riverElevatedOrWorse) {
      recommendations.add(
        'River levels near this property are elevated — monitor official flood '
        'warnings and move valuables and vehicles to higher ground now.',
      );
    }
    if (rainfallPoints >= 7) {
      recommendations.add(
        'Moderate-to-heavy rain is falling nearby right now — stay alert for '
        'flash flooding and avoid low-lying roads.',
      );
    }
    if (input.nearbyFloodCount > 0) {
      recommendations.add(
        'This area has a history of flooding — prepare an evacuation plan and emergency kit.',
      );
    }
    if (elevationPoints >= 10) {
      recommendations.add(
        'Property sits notably below the surrounding area — prioritize drainage improvements.',
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add(
        'No immediate risk reduction actions identified — maintain existing preparedness.',
      );
    }

    return RiskAssessmentResult(
      score: score,
      level: level,
      factors: factors,
      recommendations: recommendations,
    );
  }
}

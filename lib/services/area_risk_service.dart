import '../models/simulation_factor.dart';

class AreaRiskInput {
  final int nearbyHistoricalFloodCount;
  final double? currentRainfallMm;
  final List<String> nearbyReportWaterLevels;

  AreaRiskInput({
    required this.nearbyHistoricalFloodCount,
    required this.currentRainfallMm,
    required this.nearbyReportWaterLevels,
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

/// Pure scoring engine for the Home tab's ambient "flood status" badge —
/// combines the same long-term hazard baseline used by [RiskAssessmentService]
/// (historical flood frequency near the current location) with two live
/// signals it deliberately excludes: current rainfall and nearby community
/// flood reports. Unlike [RiskAssessmentService], this isn't scoped to a
/// saved property (no elevation/structure/barrier data), so it answers a
/// different question — "what's the flood situation right here, right now?"
/// — recomputed on demand rather than saved to `flood_simulation`.
class AreaRiskService {
  static const Map<String, double> _reportSeverityPoints = {
    'Low': 5,
    'Medium': 10,
    'High': 15,
  };

  AreaRiskResult assess(AreaRiskInput input) {
    final factors = <SimulationFactor>[];

    // Long-term hazard baseline: historical flood frequency (0-30 points).
    final historyPoints = (input.nearbyHistoricalFloodCount * 3)
        .clamp(0, 30)
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

    // Live signal: current rainfall intensity (0-30 points).
    final rainfallMm = input.currentRainfallMm;
    double rainfallPoints = 0;
    String rainfallDescription = 'Rainfall data unavailable';
    if (rainfallMm != null) {
      if (rainfallMm >= 15) {
        rainfallPoints = 30;
        rainfallDescription = 'Heavy rain right now (${rainfallMm.toStringAsFixed(1)}mm)';
      } else if (rainfallMm >= 7.5) {
        rainfallPoints = 20;
        rainfallDescription = 'Moderate rain right now (${rainfallMm.toStringAsFixed(1)}mm)';
      } else if (rainfallMm >= 2.5) {
        rainfallPoints = 10;
        rainfallDescription = 'Light rain right now (${rainfallMm.toStringAsFixed(1)}mm)';
      } else {
        rainfallPoints = 0;
        rainfallDescription = rainfallMm > 0
            ? 'Trace rainfall (${rainfallMm.toStringAsFixed(1)}mm)'
            : 'No rain currently';
      }
    }
    factors.add(
      SimulationFactor(
        factorName: 'Current rainfall',
        factorValue: rainfallDescription,
        scoreContribution: rainfallPoints,
      ),
    );

    // Live signal: community flood reports nearby (0-40 points) — the
    // strongest signal, since it's a direct eyewitness account rather than
    // an inference from weather or history.
    final reportPoints = input.nearbyReportWaterLevels
        .fold<double>(
          0,
          (sum, level) => sum + (_reportSeverityPoints[level] ?? 5),
        )
        .clamp(0, 40)
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

    final rawScore = factors.fold<double>(
      0,
      (sum, f) => sum + f.scoreContribution,
    );
    final score = rawScore.clamp(0, 100).toDouble();
    final level = score >= 67 ? 'High' : (score >= 34 ? 'Medium' : 'Low');

    return AreaRiskResult(score: score, level: level, factors: factors);
  }
}

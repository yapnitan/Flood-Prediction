import '../models/river_flood_data.dart';
import '../models/simulation_factor.dart';

class AreaRiskInput {
  final int nearbyHistoricalFloodCount;
  final double? currentRainfallMm;
  final String? rainfallIntensityLabel;
  final List<String> nearbyReportWaterLevels;
  final String? riverGaugeStatus;
  final bool riverGaugeRising;
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
class AreaRiskService {
  static const Map<String, double> _reportSeverityPoints = {
    'Low': 10,
    'Medium': 15,
    'High': 20,
  };

  AreaRiskResult assess(AreaRiskInput input) {
    final factors = <SimulationFactor>[];

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

import '../models/simulation_factor.dart';

class RiskAssessmentInput {
  final int nearbyFloodCount;
  final double? propertyElevationMeters;
  final double? baselineElevationMeters;
  final String structureType;
  final bool hasFloodBarriers;
  final bool hasRaisedFoundation;

  RiskAssessmentInput({
    required this.nearbyFloodCount,
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
/// already-gathered inputs. [RiskAssessmentController] is responsible for
/// fetching those inputs (historical records, terrain, weather) first.
///
/// Score (0-100, higher = riskier) combines:
///   - Historical flood frequency nearby (hazard, from the JPS/DID dataset)
///   - Property elevation relative to its district's baseline elevation
///     (hazard) — an absolute elevation number means little on its own, so
///     this compares against the local baseline instead.
///   - Structure type (vulnerability)
///   - Flood barriers / raised foundation (mitigation, subtracts points)
///
/// Current weather is deliberately NOT an input: it's an instantaneous
/// snapshot, not part of a property's persistent risk profile, so the UI
/// shows it separately as an informational "current conditions" badge.
class RiskAssessmentService {
  static const Map<String, double> structureVulnerability = {
    'Single-storey house': 10,
    'Multi-storey house': 6,
    'Apartment / Condominium': 3,
    'Shophouse / Commercial': 8,
    'Other': 6,
  };

  static List<String> get structureTypeOptions =>
      structureVulnerability.keys.toList();

  RiskAssessmentResult assess(RiskAssessmentInput input) {
    final factors = <SimulationFactor>[];

    // Hazard: historical flood frequency nearby (0-50 points, +5 each, capped).
    final historyPoints = (input.nearbyFloodCount * 5).clamp(0, 50).toDouble();
    factors.add(
      SimulationFactor(
        factorName: 'Historical flood frequency',
        factorValue: input.nearbyFloodCount == 0
            ? 'No recorded floods nearby in the JPS/DID dataset'
            : '${input.nearbyFloodCount} recorded flood(s) nearby',
        scoreContribution: historyPoints,
      ),
    );

    // Hazard: elevation relative to the district baseline (0-30 points).
    double elevationPoints = 0;
    String elevationDescription = 'Elevation data unavailable';
    if (input.propertyElevationMeters != null &&
        input.baselineElevationMeters != null) {
      final deficit =
          input.baselineElevationMeters! - input.propertyElevationMeters!;
      elevationPoints = (deficit * 3).clamp(0, 30).toDouble();
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

    // Vulnerability: structure type (0-10 points).
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
    if (input.nearbyFloodCount > 0) {
      recommendations.add(
        'This area has a history of flooding — prepare an evacuation plan and emergency kit.',
      );
    }
    if (elevationPoints >= 15) {
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

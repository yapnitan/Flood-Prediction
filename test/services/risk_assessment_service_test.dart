import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/services/risk_assessment_service.dart';

void main() {
  final service = RiskAssessmentService();

  RiskAssessmentInput baseInput({
    int nearbyFloodCount = 0,
    double? propertyElevationMeters,
    double? baselineElevationMeters,
    String structureType = 'Single-storey house',
    bool hasFloodBarriers = false,
    bool hasRaisedFoundation = false,
  }) {
    return RiskAssessmentInput(
      nearbyFloodCount: nearbyFloodCount,
      propertyElevationMeters: propertyElevationMeters,
      baselineElevationMeters: baselineElevationMeters,
      structureType: structureType,
      hasFloodBarriers: hasFloodBarriers,
      hasRaisedFoundation: hasRaisedFoundation,
    );
  }

  group('RiskAssessmentService.assess', () {
    test('a property with no history, no elevation deficit, and full mitigation scores low', () {
      final result = service.assess(baseInput(
        nearbyFloodCount: 0,
        propertyElevationMeters: 50,
        baselineElevationMeters: 50,
        hasFloodBarriers: true,
        hasRaisedFoundation: true,
      ));

      expect(result.score, greaterThanOrEqualTo(0));
      expect(result.level, 'Low');
    });

    test('score never goes negative even when mitigation outweighs hazard points', () {
      final result = service.assess(baseInput(
        nearbyFloodCount: 0,
        propertyElevationMeters: 50,
        baselineElevationMeters: 50,
        structureType: 'Apartment / Condominium', // lowest vulnerability points
        hasFloodBarriers: true,
        hasRaisedFoundation: true,
      ));

      expect(result.score, greaterThanOrEqualTo(0));
    });

    test('flood barriers strictly reduce the score versus an otherwise-identical property', () {
      final withoutBarriers = service.assess(baseInput(nearbyFloodCount: 3));
      final withBarriers = service.assess(baseInput(nearbyFloodCount: 3, hasFloodBarriers: true));

      expect(withBarriers.score, lessThan(withoutBarriers.score));
    });

    test('raised foundation strictly reduces the score versus an otherwise-identical property', () {
      final withoutFoundation = service.assess(baseInput(nearbyFloodCount: 3));
      final withFoundation = service.assess(baseInput(nearbyFloodCount: 3, hasRaisedFoundation: true));

      expect(withFoundation.score, lessThan(withoutFoundation.score));
    });

    test('lower elevation than the district baseline increases the score', () {
      final atBaseline = service.assess(baseInput(propertyElevationMeters: 50, baselineElevationMeters: 50));
      final belowBaseline = service.assess(baseInput(propertyElevationMeters: 30, baselineElevationMeters: 50));

      expect(belowBaseline.score, greaterThan(atBaseline.score));
    });

    test('elevation above the district baseline does not add elevation risk points', () {
      final result = service.assess(baseInput(propertyElevationMeters: 80, baselineElevationMeters: 50));
      final elevationFactor = result.factors.firstWhere((f) => f.factorName == 'Relative elevation');

      expect(elevationFactor.scoreContribution, 0);
    });

    test('more nearby historical floods increases the score, capped at 50 points', () {
      final none = service.assess(baseInput(nearbyFloodCount: 0));
      final some = service.assess(baseInput(nearbyFloodCount: 5));
      final many = service.assess(baseInput(nearbyFloodCount: 100));

      expect(some.score, greaterThan(none.score));
      final manyHistoryFactor = many.factors.firstWhere((f) => f.factorName == 'Historical flood frequency');
      expect(manyHistoryFactor.scoreContribution, 50);
    });

    test('score is clamped to 100 even with maximum hazard inputs', () {
      final result = service.assess(baseInput(
        nearbyFloodCount: 999,
        propertyElevationMeters: 0,
        baselineElevationMeters: 100,
        structureType: 'Single-storey house',
      ));

      expect(result.score, lessThanOrEqualTo(100));
    });

    test('risk level thresholds match the score', () {
      // Structure alone contributes 10 points (Single-storey house) -> Low.
      final low = service.assess(baseInput());
      expect(low.level, 'Low');

      // Push into High: heavy nearby history + large elevation deficit.
      final high = service.assess(baseInput(
        nearbyFloodCount: 10,
        propertyElevationMeters: 0,
        baselineElevationMeters: 20,
      ));
      expect(high.level, 'High');
    });

    test('missing elevation data is reported without contributing risk points', () {
      final result = service.assess(baseInput(propertyElevationMeters: null, baselineElevationMeters: null));
      final elevationFactor = result.factors.firstWhere((f) => f.factorName == 'Relative elevation');

      expect(elevationFactor.scoreContribution, 0);
      expect(elevationFactor.factorValue, 'Elevation data unavailable');
    });

    test('recommends flood barriers when none are present', () {
      final result = service.assess(baseInput(hasFloodBarriers: false));
      expect(
        result.recommendations.any((r) => r.toLowerCase().contains('flood barrier')),
        isTrue,
      );
    });

    test('gives a maintenance recommendation when no risk factors are present', () {
      final result = service.assess(baseInput(
        nearbyFloodCount: 0,
        hasFloodBarriers: true,
        hasRaisedFoundation: true,
        propertyElevationMeters: 50,
        baselineElevationMeters: 50,
      ));
      expect(result.recommendations, isNotEmpty);
    });
  });
}

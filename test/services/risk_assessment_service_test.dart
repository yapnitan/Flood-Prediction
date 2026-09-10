import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/river_flood_data.dart';
import 'package:flood_prediction/services/risk_assessment_service.dart';

void main() {
  final service = RiskAssessmentService();

  RiskAssessmentInput baseInput({
    int nearbyFloodCount = 0,
    List<String> recentReportWaterLevels = const [],
    double? rainfallMm,
    String? rainfallIntensityLabel,
    String? riverGaugeStatus,
    bool riverGaugeRising = false,
    RiverFloodLevel riverFloodLevel = RiverFloodLevel.unknown,
    double? propertyElevationMeters,
    double? baselineElevationMeters,
    String structureType = 'Single-storey house',
    bool hasFloodBarriers = false,
    bool hasRaisedFoundation = false,
  }) {
    return RiskAssessmentInput(
      nearbyFloodCount: nearbyFloodCount,
      recentReportWaterLevels: recentReportWaterLevels,
      rainfallMm: rainfallMm,
      rainfallIntensityLabel: rainfallIntensityLabel,
      riverGaugeStatus: riverGaugeStatus,
      riverGaugeRising: riverGaugeRising,
      riverFloodLevel: riverFloodLevel,
      propertyElevationMeters: propertyElevationMeters,
      baselineElevationMeters: baselineElevationMeters,
      structureType: structureType,
      hasFloodBarriers: hasFloodBarriers,
      hasRaisedFoundation: hasRaisedFoundation,
    );
  }

  double factor(RiskAssessmentResult r, String name) =>
      r.factors.firstWhere((f) => f.factorName == name).scoreContribution;

  group('RiskAssessmentService.assess', () {
    test('the hazard/vulnerability factor caps add up to exactly 100', () {
      final r = service.assess(baseInput(
        nearbyFloodCount: 99, // history -> 25
        recentReportWaterLevels: const ['High', 'High'], // reports -> 20
        rainfallIntensityLabel: 'Very Heavy', // rainfall -> 10
        riverGaugeStatus: 'Danger', // river -> 15
        propertyElevationMeters: 0,
        baselineElevationMeters: 100, // elevation -> 20
        structureType: 'Single-storey house', // structure -> 10
      ));
      expect(
        factor(r, 'Historical flood frequency') +
            factor(r, 'Recent community flood reports') +
            factor(r, 'Current rainfall') +
            factor(r, 'Nearby river level') +
            factor(r, 'Relative elevation') +
            factor(r, 'Structure type'),
        100,
      );
      expect(r.score, 100);
      expect(r.level, 'High');
    });

    test('historical floods score +5 each, capped at 25', () {
      expect(factor(service.assess(baseInput(nearbyFloodCount: 3)),
          'Historical flood frequency'), 15);
      expect(factor(service.assess(baseInput(nearbyFloodCount: 40)),
          'Historical flood frequency'), 25);
    });

    test('community reports scored by severity (10/15/20), capped 20', () {
      double reports(List<String> levels) => factor(
            service.assess(baseInput(recentReportWaterLevels: levels)),
            'Recent community flood reports',
          );
      expect(reports(const []), 0);
      expect(reports(const ['Low']), 10);
      expect(reports(const ['High']), 20);
      expect(reports(const ['Medium', 'High']), 20); // 35 -> capped
    });

    test('rainfall factor uses JPS bands (label first, then mm)', () {
      double rainLabel(String l) => factor(
            service.assess(baseInput(rainfallIntensityLabel: l)),
            'Current rainfall',
          );
      expect(rainLabel('No Rainfall'), 0);
      expect(rainLabel('Light'), 4);
      expect(rainLabel('Moderate'), 7);
      expect(rainLabel('Heavy'), 10);

      double rainMm(double mm) => factor(
            service.assess(baseInput(rainfallMm: mm)),
            'Current rainfall',
          );
      expect(rainMm(1), 0);
      expect(rainMm(5), 4);
      expect(rainMm(20), 7);
      expect(rainMm(45), 10);
    });

    test('river: InfoBanjir gauge status beats the GloFAS forecast', () {
      double river({String? status, bool rising = false, RiverFloodLevel glofas = RiverFloodLevel.unknown}) =>
          factor(
            service.assess(baseInput(
              riverGaugeStatus: status,
              riverGaugeRising: rising,
              riverFloodLevel: glofas,
            )),
            'Nearby river level',
          );
      // gauge
      expect(river(status: 'Danger', glofas: RiverFloodLevel.normal), 15);
      expect(river(status: 'Warning'), 11);
      expect(river(status: 'Alert'), 6);
      expect(river(status: 'Normal'), 0);
      expect(river(status: 'Normal', rising: true), 2);
      // GloFAS fallback (no gauge)
      expect(river(glofas: RiverFloodLevel.elevated), 6);
      expect(river(glofas: RiverFloodLevel.high), 11);
      expect(river(glofas: RiverFloodLevel.unknown), 0);
    });

    test('lower elevation than the district baseline increases the score, cap 20',
        () {
      expect(
        factor(
          service.assess(baseInput(
              propertyElevationMeters: 50, baselineElevationMeters: 50)),
          'Relative elevation',
        ),
        0,
      );
      expect(
        factor(
          service.assess(baseInput(
              propertyElevationMeters: 47, baselineElevationMeters: 50)),
          'Relative elevation',
        ),
        12, // 3 m deficit * 4
      );
      expect(
        factor(
          service.assess(baseInput(
              propertyElevationMeters: 0, baselineElevationMeters: 50)),
          'Relative elevation',
        ),
        20, // capped
      );
    });

    test('elevation above the baseline adds no points', () {
      expect(
        factor(
          service.assess(baseInput(
              propertyElevationMeters: 80, baselineElevationMeters: 50)),
          'Relative elevation',
        ),
        0,
      );
    });

    test('flood barriers and a raised foundation each reduce the score', () {
      final plain = service.assess(baseInput(nearbyFloodCount: 3)).score;
      final barriers =
          service.assess(baseInput(nearbyFloodCount: 3, hasFloodBarriers: true))
              .score;
      final foundation = service
          .assess(baseInput(nearbyFloodCount: 3, hasRaisedFoundation: true))
          .score;
      expect(barriers, lessThan(plain));
      expect(foundation, lessThan(plain));
    });

    test('score is clamped to 0-100', () {
      final maxed = service.assess(baseInput(
        nearbyFloodCount: 999,
        recentReportWaterLevels: const ['High', 'High', 'High'],
        rainfallIntensityLabel: 'Very Heavy',
        riverGaugeStatus: 'Danger',
        propertyElevationMeters: 0,
        baselineElevationMeters: 100,
      ));
      expect(maxed.score, 100);

      final floored = service.assess(baseInput(
        propertyElevationMeters: 50,
        baselineElevationMeters: 50,
        structureType: 'Apartment / Condominium',
        hasFloodBarriers: true,
        hasRaisedFoundation: true,
      ));
      expect(floored.score, greaterThanOrEqualTo(0));
    });

    test('risk level thresholds match the score', () {
      expect(service.assess(baseInput()).level, 'Low');
      expect(
        service
            .assess(baseInput(
              nearbyFloodCount: 10, // 25
              riverGaugeStatus: 'Danger', // 15
              rainfallIntensityLabel: 'Heavy', // 10
              propertyElevationMeters: 30,
              baselineElevationMeters: 50, // 20 m? deficit 20 -> capped 20
            ))
            .level,
        'High',
      );
    });

    group('recommendations', () {
      test('monitoring when neighbours reported flooding recently', () {
        final r = service.assess(baseInput(recentReportWaterLevels: const ['Low']));
        expect(
          r.recommendations.any((x) => x.toLowerCase().contains('neighbour')),
          isTrue,
        );
      });

      test('river warning when the gauge/forecast is elevated', () {
        final r = service.assess(baseInput(riverGaugeStatus: 'Warning'));
        expect(
          r.recommendations.any((x) => x.toLowerCase().contains('river levels')),
          isTrue,
        );
      });

      test('flash-flood note when moderate/heavy rain is falling', () {
        final r = service.assess(baseInput(rainfallIntensityLabel: 'Heavy'));
        expect(
          r.recommendations.any((x) => x.toLowerCase().contains('flash flood')),
          isTrue,
        );
      });

      test('flood barriers when none present', () {
        final r = service.assess(baseInput(hasFloodBarriers: false));
        expect(
          r.recommendations.any((x) => x.toLowerCase().contains('flood barrier')),
          isTrue,
        );
      });

      test('a maintenance line when nothing else applies', () {
        final r = service.assess(baseInput(
          hasFloodBarriers: true,
          hasRaisedFoundation: true,
          propertyElevationMeters: 50,
          baselineElevationMeters: 50,
        ));
        expect(r.recommendations, isNotEmpty);
      });
    });
  });
}

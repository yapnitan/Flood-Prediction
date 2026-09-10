import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/river_flood_data.dart';
import 'package:flood_prediction/services/area_risk_service.dart';

void main() {
  final service = AreaRiskService();

  double factor(AreaRiskResult r, String name) =>
      r.factors.firstWhere((f) => f.factorName.contains(name)).scoreContribution;

  group('AreaRiskService.assess', () {
    test('all-clear scores zero / Low', () {
      final r = service.assess(AreaRiskInput(
        nearbyHistoricalFloodCount: 0,
        currentRainfallMm: 0,
        nearbyReportWaterLevels: const [],
      ));
      expect(r.score, 0);
      expect(r.level, 'Low');
    });

    test('historical floods score +5 each, capped at 40', () {
      expect(
        factor(
          service.assess(AreaRiskInput(
            nearbyHistoricalFloodCount: 3,
            currentRainfallMm: 0,
            nearbyReportWaterLevels: const [],
          )),
          'Historical',
        ),
        15,
      );
      expect(
        factor(
          service.assess(AreaRiskInput(
            nearbyHistoricalFloodCount: 20,
            currentRainfallMm: 0,
            nearbyReportWaterLevels: const [],
          )),
          'Historical',
        ),
        40,
      );
    });

    test('community reports score Low 10 / Medium 15 / High 20, capped 40', () {
      expect(
        factor(
          service.assess(AreaRiskInput(
            nearbyHistoricalFloodCount: 0,
            currentRainfallMm: 0,
            nearbyReportWaterLevels: const ['Low', 'Medium', 'High'],
          )),
          'Community',
        ),
        40, // 10 + 15 + 20 = 45 -> capped
      );
      expect(
        factor(
          service.assess(AreaRiskInput(
            nearbyHistoricalFloodCount: 0,
            currentRainfallMm: 0,
            nearbyReportWaterLevels: const ['Low', 'Low'],
          )),
          'Community',
        ),
        20,
      );
    });

    test('river forecast scores 0 / 6 / 12', () {
      double river(RiverFloodLevel level) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: 0,
              nearbyReportWaterLevels: const [],
              riverFloodLevel: level,
            )),
            'river flood forecast',
          );
      expect(river(RiverFloodLevel.unknown), 0);
      expect(river(RiverFloodLevel.normal), 0);
      expect(river(RiverFloodLevel.elevated), 6);
      expect(river(RiverFloodLevel.high), 12);
    });

    test('rainfall bands: light 10 / moderate 20 / heavy 30, unavailable 0', () {
      double rain(double? mm) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: mm,
              nearbyReportWaterLevels: const [],
            )),
            'rainfall',
          );
      expect(rain(null), 0);
      expect(rain(0), 0);
      expect(rain(5), 10);
      expect(rain(10), 20);
      expect(rain(20), 30);
    });

    test('a bad combination reaches High', () {
      final r = service.assess(AreaRiskInput(
        nearbyHistoricalFloodCount: 10, // 40
        currentRainfallMm: 20, // 30
        nearbyReportWaterLevels: const ['High'], // 20
        riverFloodLevel: RiverFloodLevel.high, // 12
      ));
      expect(r.score, 100); // 102 clamped
      expect(r.level, 'High');
    });
  });
}

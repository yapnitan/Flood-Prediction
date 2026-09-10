import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/river_flood_data.dart';
import 'package:flood_prediction/services/area_risk_service.dart';

void main() {
  final service = AreaRiskService();

  double factor(AreaRiskResult r, String name) =>
      r.factors.firstWhere((f) => f.factorName.contains(name)).scoreContribution;

  group('AreaRiskService.assess', () {
    test('the four factor caps add up to exactly 100', () {
      final r = service.assess(AreaRiskInput(
        nearbyHistoricalFloodCount: 99, // -> 25
        currentRainfallMm: 200, // -> 25 (heavy)
        nearbyReportWaterLevels: const ['High', 'High'], // -> 30
        riverGaugeStatus: 'Danger', // -> 20
      ));
      expect(
        r.factors.fold<double>(0, (s, f) => s + f.scoreContribution),
        100,
      );
      expect(r.score, 100);
      expect(r.level, 'High');
    });

    test('all-clear scores zero / Low', () {
      final r = service.assess(AreaRiskInput(
        nearbyHistoricalFloodCount: 0,
        currentRainfallMm: 0,
        nearbyReportWaterLevels: const [],
      ));
      expect(r.score, 0);
      expect(r.level, 'Low');
    });

    test('historical floods score +5 each, capped at 25', () {
      double history(int n) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: n,
              currentRainfallMm: 0,
              nearbyReportWaterLevels: const [],
            )),
            'Historical',
          );
      expect(history(3), 15);
      expect(history(20), 25);
    });

    test('community reports score Low 10 / Medium 15 / High 20, capped 30', () {
      double reports(List<String> levels) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: 0,
              nearbyReportWaterLevels: levels,
            )),
            'Community',
          );
      expect(reports(const ['Low', 'Low']), 20);
      expect(reports(const ['Low', 'Medium', 'High']), 30); // 45 -> capped
    });

    test('river GloFAS fallback scores 0 / 8 / 15', () {
      double river(RiverFloodLevel level) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: 0,
              nearbyReportWaterLevels: const [],
              riverFloodLevel: level,
            )),
            'river level',
          );
      expect(river(RiverFloodLevel.unknown), 0);
      expect(river(RiverFloodLevel.normal), 0);
      expect(river(RiverFloodLevel.elevated), 8);
      expect(river(RiverFloodLevel.high), 15);
    });

    test('InfoBanjir river gauge status takes priority over the forecast', () {
      double river(String status, {bool rising = false}) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: 0,
              nearbyReportWaterLevels: const [],
              riverGaugeStatus: status,
              riverGaugeRising: rising,
              // forecast says "high" but the gauge should win:
              riverFloodLevel: RiverFloodLevel.high,
            )),
            'river level',
          );
      expect(river('Danger'), 20);
      expect(river('Warning'), 15);
      expect(river('Alert'), 8);
      expect(river('Normal'), 0);
      expect(river('Normal', rising: true), 3);
    });

    test('rainfall mm fallback bands match JPS hourly classes', () {
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
      expect(rain(1), 0); // trace
      expect(rain(5), 10); // light
      expect(rain(20), 18); // moderate
      expect(rain(45), 25); // heavy
    });

    test('rainfall uses the JPS gauge intensity label when present', () {
      double rain(String label, {double mm = 0}) => factor(
            service.assess(AreaRiskInput(
              nearbyHistoricalFloodCount: 0,
              currentRainfallMm: mm,
              rainfallIntensityLabel: label,
              nearbyReportWaterLevels: const [],
            )),
            'rainfall',
          );
      expect(rain('No Rainfall'), 0);
      expect(rain('Light'), 10);
      expect(rain('Moderate'), 18);
      expect(rain('Heavy'), 25);
      expect(rain('Very Heavy'), 25);
      // label wins even if the mm value would band differently
      expect(rain('Light', mm: 45), 10);
    });

    test('a middling combination reaches Medium', () {
      final r = service.assess(AreaRiskInput(
        nearbyHistoricalFloodCount: 3, // 15
        currentRainfallMm: 20, // 18 (moderate)
        nearbyReportWaterLevels: const ['Low'], // 10
        riverGaugeStatus: 'Normal', // 0
      ));
      expect(r.score, 43);
      expect(r.level, 'Medium');
    });
  });
}

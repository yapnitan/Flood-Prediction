import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/river_flood_data.dart';

void main() {
  group('RiverFloodData.level', () {
    RiverFloodData data(double? recentMean, double? forecastMax) => RiverFloodData(
          recentMean: recentMean,
          forecastMax: forecastMax,
        );

    test('unknown when the river is not modelled here', () {
      expect(data(null, null).level, RiverFloodLevel.unknown);
      expect(data(0, 10).level, RiverFloodLevel.unknown); // no usable baseline
    });

    test('buckets the forecast-peak / recent-average ratio', () {
      expect(data(100, 50).level, RiverFloodLevel.low); // 0.5x
      expect(data(100, 110).level, RiverFloodLevel.normal); // 1.1x
      expect(data(100, 150).level, RiverFloodLevel.elevated); // 1.5x
      expect(data(100, 260).level, RiverFloodLevel.high); // 2.6x
    });

    test('unknown has no description; the others do', () {
      expect(RiverFloodLevel.unknown.description, isNull);
      expect(RiverFloodLevel.elevated.description, isNotNull);
      expect(RiverFloodLevel.high.description, isNotNull);
    });

    test('fromKey round-trips and falls back to unknown', () {
      for (final level in RiverFloodLevel.values) {
        expect(RiverFloodLevelInfo.fromKey(level.key), level);
      }
      expect(RiverFloodLevelInfo.fromKey('nonsense'), RiverFloodLevel.unknown);
      expect(RiverFloodLevelInfo.fromKey(null), RiverFloodLevel.unknown);
    });
  });
}

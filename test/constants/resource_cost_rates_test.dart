import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/constants/resource_cost_rates.dart';

void main() {
  group('ResourceCostRates.calculate', () {
    test('sums the per-person per-day rates for a single day', () {
      final cost = ResourceCostRates.calculate(
        adults: 2, // 2 * 50
        children: 1, // 1 * 35
        elderly: 0,
        infants: 0,
        personsWithDisabilities: 0,
      );
      expect(cost, 135);
    });

    test('multiplies by the number of days', () {
      final oneDay = ResourceCostRates.calculate(
        adults: 3,
        children: 0,
        elderly: 0,
        infants: 0,
        personsWithDisabilities: 0,
      );
      final threeDays = ResourceCostRates.calculate(
        adults: 3,
        children: 0,
        elderly: 0,
        infants: 0,
        personsWithDisabilities: 0,
        days: 3,
      );
      expect(threeDays, oneDay * 3);
    });

    test('treats a non-positive day count as one day', () {
      final base = ResourceCostRates.calculate(
        adults: 1,
        children: 0,
        elderly: 0,
        infants: 0,
        personsWithDisabilities: 0,
      );
      expect(
        ResourceCostRates.calculate(
          adults: 1,
          children: 0,
          elderly: 0,
          infants: 0,
          personsWithDisabilities: 0,
          days: 0,
        ),
        base,
      );
    });

    test('an empty shelter costs nothing', () {
      expect(
        ResourceCostRates.calculate(
          adults: 0,
          children: 0,
          elderly: 0,
          infants: 0,
          personsWithDisabilities: 0,
          days: 5,
        ),
        0,
      );
    });
  });
}

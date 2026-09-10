import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/models/infobanjir_station.dart';

void main() {
  // Shape of a real InfoBanjir feed record (single-letter keys).
  Map<String, dynamic> record({
    String i = 'RF,WL',
    String? u = '44', // rainfall 1h
    String yRain = '10/09/2026 15:15',
    String? m = '23.68', // water level
    String o = '23', // normal level
    String p = '0.68', // above normal
    String? n = 'Normal', // status
    String s = 'Rising', // trend
    String qWl = '10/09/2026 15:30',
    String c = '3.138589',
    String d = '101.69455',
  }) =>
      {
        'a': '26523',
        'b': 'Sg. Klang di Jambatan Sulaiman (F2)',
        'c': c,
        'd': d,
        'e': 'Kuala Lumpur',
        'i': i,
        'u': u,
        'v': '44',
        'w': '55',
        'x': 'Heavy',
        'y': yRain,
        'm': m,
        'o': o,
        'p': p,
        'n': n,
        's': s,
        'q': qWl,
      };

  String recentMyt() {
    final l = DateTime.now().toUtc().add(const Duration(hours: 8));
    String pad(int x) => x.toString().padLeft(2, '0');
    return '${pad(l.day)}/${pad(l.month)}/${l.year} ${pad(l.hour)}:${pad(l.minute)}';
  }

  group('InfoBanjirStation.fromJson', () {
    test('maps rainfall and water-level keys', () {
      final st = InfoBanjirStation.fromJson(record());
      expect(st.id, '26523');
      expect(st.latitude, closeTo(3.1386, 0.001));
      expect(st.measuresRainfall, isTrue);
      expect(st.measuresWaterLevel, isTrue);
      expect(st.rainfall1hMm, 44);
      expect(st.waterLevelM, closeTo(23.68, 0.001));
      expect(st.normalLevelM, 23);
      expect(st.metresAboveNormal, closeTo(0.68, 0.001));
      expect(st.waterLevelStatus, 'Normal');
      expect(st.waterLevelTrend, 'Rising');
      expect(st.isRising, isTrue);
    });

    test('sentinels become null', () {
      expect(InfoBanjirStation.fromJson(record(u: '-9999')).rainfall1hMm, isNull);
      expect(InfoBanjirStation.fromJson(record(m: '-9999')).waterLevelM, isNull);
      expect(InfoBanjirStation.fromJson(record(m: '')).waterLevelM, isNull);
    });

    test('hasFreshRainfall / hasFreshWaterLevel honour age', () {
      final fresh = InfoBanjirStation.fromJson(
        record(yRain: recentMyt(), qWl: recentMyt()),
      );
      expect(fresh.hasFreshRainfall(), isTrue);
      expect(fresh.hasFreshWaterLevel(), isTrue);

      final stale = InfoBanjirStation.fromJson(
        record(yRain: '01/01/2020 08:00', qWl: '01/01/2020 08:00'),
      );
      expect(stale.hasFreshRainfall(), isFalse);
      expect(stale.hasFreshWaterLevel(), isFalse);
    });

    test('an Error status is not a fresh water-level reading', () {
      final st = InfoBanjirStation.fromJson(
        record(n: 'Error', qWl: recentMyt()),
      );
      expect(st.hasFreshWaterLevel(), isFalse);
    });

    test('rainfall-only station does not report water level', () {
      final st = InfoBanjirStation.fromJson(record(i: 'RF'));
      expect(st.measuresRainfall, isTrue);
      expect(st.measuresWaterLevel, isFalse);
    });
  });
}

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/utils/currency_input.dart';

void main() {
  const formatter = CurrencyInputFormatter();

  String format(String input) {
    final result = formatter.formatEditUpdate(
      const TextEditingValue(),
      TextEditingValue(
        text: input,
        selection: TextSelection.collapsed(offset: input.length),
      ),
    );
    return result.text;
  }

  group('CurrencyInputFormatter', () {
    test('groups the integer part with commas', () {
      expect(format('1234'), '1,234');
      expect(format('1234567'), '1,234,567');
      expect(format('1000000'), '1,000,000');
    });

    test('keeps at most two decimal places', () {
      expect(format('1234.5'), '1,234.5');
      expect(format('1234.56'), '1,234.56');
      expect(format('1234.567'), '1,234.56');
    });

    test('normalises a bare or leading decimal point', () {
      expect(format('.5'), '0.5');
      expect(format('12.'), '12.');
    });

    test('strips leading zeros but keeps a single zero', () {
      expect(format('007'), '7');
      expect(format('00'), '0');
      expect(format('0.50'), '0.50');
    });

    test('ignores non-numeric characters', () {
      expect(format('abc1x2y3'), '123');
      expect(format('RM 1,234'), '1,234');
    });

    test('is idempotent on already-formatted input', () {
      expect(format('1,234.56'), '1,234.56');
    });

    test('empty stays empty', () {
      expect(format(''), '');
      expect(format('abc'), '');
    });
  });

  group('parse', () {
    test('drops grouping commas', () {
      expect(CurrencyInputFormatter.parse('1,234.56'), 1234.56);
      expect(CurrencyInputFormatter.parse('1,000,000'), 1000000);
    });

    test('returns null for non-numbers', () {
      expect(CurrencyInputFormatter.parse(''), isNull);
      expect(CurrencyInputFormatter.parse(null), isNull);
      expect(CurrencyInputFormatter.parse('RM'), isNull);
    });
  });

  group('display helpers', () {
    test('formatAmount is two-dp and comma-grouped, no symbol', () {
      expect(formatAmount(1234.5), '1,234.50');
      expect(formatAmount(0), '0.00');
      expect(formatAmount(1000000), '1,000,000.00');
    });

    test('formatRinggit prefixes RM', () {
      expect(formatRinggit(1234.5), 'RM 1,234.50');
    });
  });
}

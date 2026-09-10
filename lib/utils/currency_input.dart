import 'package:flutter/services.dart';

/// Groups a run of digits into thousands with commas: `1234567` -> `1,234,567`.
String groupThousands(String digits) {
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// `1234.5` -> `1,234.50`. Always two decimal places, comma-grouped, no
/// currency symbol — use this to seed a money `TextField` so its initial
/// value already matches what [CurrencyInputFormatter] would produce.
String formatAmount(num amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  return '${groupThousands(parts[0])}.${parts[1]}';
}

/// `1234.5` -> `RM 1,234.50`. Always two decimal places, comma-grouped.
String formatRinggit(num amount) => 'RM ${formatAmount(amount)}';

/// Live-formats a money `TextField` as the user types: digits only, one
/// decimal point, at most two decimal places, integer part comma-grouped
/// (e.g. `1,234.56`). Pair it with [parse] when reading the value back.
class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  /// Turns a formatted field value (`1,234.5`) back into a number, or null.
  static double? parse(String? text) =>
      double.tryParse((text ?? '').replaceAll(',', '').trim());

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Keep only digits and the first decimal point.
    final cleaned = StringBuffer();
    var seenDot = false;
    for (final ch in newValue.text.split('')) {
      if (ch == '.' && !seenDot) {
        seenDot = true;
        cleaned.write('.');
      } else if (ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39) {
        cleaned.write(ch);
      }
    }

    var value = cleaned.toString();
    final dot = value.indexOf('.');

    String intPart = dot == -1 ? value : value.substring(0, dot);
    String? fracPart = dot == -1 ? null : value.substring(dot + 1);
    if (fracPart != null && fracPart.length > decimalDigits) {
      fracPart = fracPart.substring(0, decimalDigits);
    }

    // Drop leading zeros, but leave a single "0" (or "0.xx").
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart.isEmpty) intPart = dot == -1 ? '' : '0';
    if (intPart.isEmpty && fracPart == null) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = fracPart == null
        ? groupThousands(intPart)
        : '${groupThousands(intPart)}.$fracPart';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Clamps a comma-grouped numeric field to [max] — typing (or pasting) past
/// it snaps the value straight down to [max] rather than rejecting the
/// keystroke. Pair with [CurrencyInputFormatter] and list it after that
/// formatter so it clamps the already-grouped value; pass the same
/// [decimalDigits] as that formatter so the clamped value's formatting
/// matches (e.g. `1,000,000,000.00` rather than a bare whole number).
class MaxValueInputFormatter extends TextInputFormatter {
  const MaxValueInputFormatter(this.max, {this.decimalDigits = 0});

  final num max;
  final int decimalDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue;
    final value = double.tryParse(digits);
    if (value == null || value <= max) return newValue;

    final clamped = decimalDigits > 0
        ? formatAmount(max)
        : groupThousands(max.toString());
    return TextEditingValue(
      text: clamped,
      selection: TextSelection.collapsed(offset: clamped.length),
    );
  }
}

import 'package:flutter/services.dart';

String groupThousands(String digits) {
  if (digits.length <= 3) return digits;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i != 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
String formatAmount(num amount) {
  final parts = amount.toStringAsFixed(2).split('.');
  return '${groupThousands(parts[0])}.${parts[1]}';
}

String formatRinggit(num amount) => 'RM ${formatAmount(amount)}';

class CurrencyInputFormatter extends TextInputFormatter {
  const CurrencyInputFormatter({this.decimalDigits = 2});

  final int decimalDigits;

  static double? parse(String? text) =>
      double.tryParse((text ?? '').replaceAll(',', '').trim());

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

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

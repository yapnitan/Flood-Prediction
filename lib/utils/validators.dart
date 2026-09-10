
library;

import 'package:flutter/services.dart';

class WordCountInputFormatter extends TextInputFormatter {
  const WordCountInputFormatter(this.maxWords);

  final int maxWords;

  static int _wordCount(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final isGrowing = newValue.text.length > oldValue.text.length;
    if (isGrowing && _wordCount(oldValue.text) >= maxWords) return oldValue;
    if (_wordCount(newValue.text) > maxWords) return oldValue;
    return newValue;
  }
}

final RegExp phoneNumberPattern = RegExp(r'^\d{10,11}$');

String? validatePhoneNumber(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (!phoneNumberPattern.hasMatch(trimmed)) {
    return 'Enter a 10 or 11 digit phone number.';
  }
  return null;
}

String? requiredPhoneNumber(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Enter a phone number.';
  return validatePhoneNumber(value);
}
const double minValidLatitude = -5;
const double maxValidLatitude = 15;
const double minValidLongitude = 90;
const double maxValidLongitude = 125;

String? validateLatitude(double? value) {
  if (value == null) return 'Enter a latitude.';
  if (value < minValidLatitude || value > maxValidLatitude) {
    return 'Latitude looks out of range for Malaysia.';
  }
  return null;
}

String? validateLongitude(double? value) {
  if (value == null) return 'Enter a longitude.';
  if (value < minValidLongitude || value > maxValidLongitude) {
    return 'Longitude looks out of range for Malaysia.';
  }
  return null;
}

const String passwordPolicyHint =
    'At least 8 characters, with an uppercase letter, a lowercase letter, a '
    'number, and a symbol.';

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Please enter a password';

  final missing = <String>[
    if (password.length < 8) 'at least 8 characters',
    if (!RegExp(r'[A-Z]').hasMatch(password)) 'an uppercase letter',
    if (!RegExp(r'[a-z]').hasMatch(password)) 'a lowercase letter',
    if (!RegExp(r'[0-9]').hasMatch(password)) 'a number',
    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) 'a symbol',
  ];
  if (missing.isEmpty) return null;
  return 'Password needs ${missing.join(', ')}.';
}

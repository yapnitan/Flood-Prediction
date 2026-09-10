/// Shared input-validation helpers (Task 15). Mirrors the phone-number
/// pattern already used ad hoc in submit_report.dart, so it's one rule
/// instead of every form re-deriving its own regex.
library;

import 'package:flutter/services.dart';

/// Caps a field at [maxWords] words. Once the field already holds that many
/// words, no further typing/pasting is accepted at all (any edit that grows
/// the text is rejected outright, kept at [oldValue]) — not just edits that
/// would add a 21st word. Deleting (shrinking the text) is always allowed,
/// so the user can never get stuck unable to backspace. Pair with a
/// `validator` that re-checks the same limit as a submit-time safety net
/// (e.g. against an over-limit value set programmatically via
/// `controller.text = ...`, which this formatter never sees).
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

/// No spaces, dashes, or country-code symbols — 10 or 11 digits.
final RegExp phoneNumberPattern = RegExp(r'^\d{10,11}$');

/// Returns an error message, or null if [value] is valid. Empty values are
/// treated as unset — pass a separate "required" check where a phone
/// number is mandatory (see [requiredPhoneNumber]).
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

/// Malaysia sits roughly within 0.5–7.5°N, 99–120°E (covering both
/// Peninsular and East Malaysia) — coordinates a user types in manually
/// (rather than picking on the map) outside a generous margin of that box
/// are almost certainly a typo, not a real property location.
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

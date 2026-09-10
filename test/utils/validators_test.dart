import 'package:flutter_test/flutter_test.dart';
import 'package:flood_prediction/utils/validators.dart';

void main() {
  group('validatePhoneNumber', () {
    test('accepts a 10-digit number', () {
      expect(validatePhoneNumber('0123456789'), isNull);
    });

    test('accepts an 11-digit number', () {
      expect(validatePhoneNumber('01234567890'), isNull);
    });

    test('treats an empty value as valid (optional field)', () {
      expect(validatePhoneNumber(''), isNull);
      expect(validatePhoneNumber(null), isNull);
    });

    test('rejects a number that is too short', () {
      expect(validatePhoneNumber('12345'), isNotNull);
    });

    test('rejects dashes and spaces', () {
      expect(validatePhoneNumber('012-345-6789'), isNotNull);
      expect(validatePhoneNumber('012 345 6789'), isNotNull);
    });

    test('rejects a country-code prefix', () {
      expect(validatePhoneNumber('+60123456789'), isNotNull);
    });
  });

  group('requiredPhoneNumber', () {
    test('rejects an empty value', () {
      expect(requiredPhoneNumber(''), isNotNull);
      expect(requiredPhoneNumber(null), isNotNull);
    });

    test('accepts a valid number', () {
      expect(requiredPhoneNumber('0123456789'), isNull);
    });
  });

  group('coordinate validators', () {
    test('accepts coordinates within the Malaysia bounding box', () {
      expect(validateLatitude(3.1390), isNull);
      expect(validateLongitude(101.6869), isNull);
    });

    test('rejects a null coordinate', () {
      expect(validateLatitude(null), isNotNull);
      expect(validateLongitude(null), isNotNull);
    });

    test('rejects an out-of-range latitude/longitude', () {
      expect(validateLatitude(200), isNotNull);
      expect(validateLongitude(-50), isNotNull);
    });
  });

  group('validatePassword', () {
    test('accepts a password meeting every rule', () {
      expect(validatePassword('Abcdef1!'), isNull);
      expect(validatePassword('Str0ng#Pass'), isNull);
    });

    test('rejects an empty password', () {
      expect(validatePassword(''), 'Please enter a password');
      expect(validatePassword(null), 'Please enter a password');
    });

    test('rejects a password that is too short', () {
      expect(validatePassword('Ab1!'), contains('at least 8 characters'));
    });

    test('rejects a missing character class', () {
      expect(validatePassword('abcdef1!'), contains('an uppercase letter'));
      expect(validatePassword('ABCDEF1!'), contains('a lowercase letter'));
      expect(validatePassword('Abcdefg!'), contains('a number'));
      expect(validatePassword('Abcdefg1'), contains('a symbol'));
    });
  });
}

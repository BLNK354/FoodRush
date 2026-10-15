import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/shared/password_strength.dart';
import 'package:foodrush/shared/validation.dart';

void main() {
  group('ratePassword', () {
    PasswordStrength level(String pw) => ratePassword(pw).$1;

    test('short passwords are weak', () {
      expect(level('Ab1!'), PasswordStrength.weak);
    });
    test('common and repeated passwords are weak however long', () {
      expect(level('password123456'), PasswordStrength.weak);
      expect(level('aaaaaaaaaaaaaa'), PasswordStrength.weak);
      expect(level('MyFoodRush2024!'), PasswordStrength.weak);
    });
    test('strength grows with length and variety', () {
      expect(level('sunsetbeach'), PasswordStrength.weak);
      expect(level('sunsetbeach7'), PasswordStrength.fair);
      expect(level('Sunsetbeach7'), PasswordStrength.good);
      expect(level('Sunset-beach-7'), PasswordStrength.strong);
    });
    test('suggests the next improvement, none when strong', () {
      expect(ratePassword('sunsetbea').$2, 'Use 12 or more characters');
      expect(ratePassword('sunsetbeach7').$2, 'Mix upper and lower case');
      expect(ratePassword('Sunset-beach-7').$2, isNull);
    });
  });

  group('validateStudentNumber', () {
    test('is required', () {
      expect(validateStudentNumber(''), isNotNull);
      expect(validateStudentNumber('   '), isNotNull);
      expect(validateStudentNumber(null), isNotNull);
    });
    test('accepts digits and dashes', () {
      expect(validateStudentNumber('2024-12345'), isNull);
      expect(validateStudentNumber('202412345'), isNull);
    });
    test('rejects letters, too short and too long', () {
      expect(validateStudentNumber('abc-123'), isNotNull);
      expect(validateStudentNumber('12-'), isNotNull);
      expect(validateStudentNumber('1' * 21), isNotNull);
    });
  });
}

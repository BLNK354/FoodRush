import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/shared/validation.dart';

void main() {
  group('bad-word filter', () {
    for (final bad in [
      'fuck', 'FUCK you', 'f*ck', 'fuuuuck', 'f u c k', 'sh1t', 'b1tch',
      'putangina mo', 'putanginamo', 'TANGINA', 't4ng1na', 'gago ka',
      'ang bobo', 'ulol', 'p0kp0k', 'motherfucker',
      // found while abuse-testing the promo-code box
      'tangnamo', 'tang!na mo', 'TNGINA', 'putang na',
    ]) {
      test('blocks "$bad"', () => expect(containsBadWords(bad), isTrue));
    }
    for (final ok in [
      'Shiitake pasta', 'computer science', 'Juan dela Cruz', 'Tangerine juice',
      'Bobotie rice bowl', 'Pass the ketchup', 'Assortment of snacks',
      'Dickens Street', 'Gagong', 'Scunthorpe',
    ]) {
      test('allows "$ok"', () => expect(containsBadWords(ok), isFalse));
    }
  });

  group('validators', () {
    test('names', () {
      expect(validatePersonName('Juan dela Cruz'), isNull);
      expect(validatePersonName('María Ñoño-O\'Neil'), isNull);
      expect(validatePersonName(''), isNotNull);
      expect(validatePersonName('J'), isNotNull);
      expect(validatePersonName('x' * 61), isNotNull);
      expect(validatePersonName('R0bert'), isNotNull);
      expect(validatePersonName('<script>'), isNotNull);
      expect(validatePersonName('Gago Ka'), isNotNull);
    });

    test('money rejects junk and extremes', () {
      for (final bad in ['-50', '0', '0.00', 'NaN', 'Infinity', '1e9', '12.345', 'abc', '10001', ' ']) {
        expect(validateMoney(bad), isNotNull, reason: bad);
      }
      for (final ok in ['1', '75', '75.5', '75.50', '10000']) {
        expect(validateMoney(ok), isNull, reason: ok);
      }
    });

    test('stock', () {
      expect(validateWholeNumber('', min: 0, max: Limits.maxStock), isNull);
      expect(validateWholeNumber('-1', min: 0, max: Limits.maxStock), isNotNull);
      expect(validateWholeNumber('10000', min: 0, max: Limits.maxStock), isNotNull);
      expect(validateWholeNumber('2.5', min: 0, max: Limits.maxStock), isNotNull);
      expect(validateWholeNumber('99999999999', min: 0, max: Limits.maxStock), isNotNull);
    });

    test('phone', () {
      expect(validatePhone('09171234567'), isNull);
      expect(validatePhone('+639171234567'), isNull);
      expect(validatePhone('0917-123-4567'), isNull);
      expect(validatePhone('12345'), isNotNull);
      expect(validatePhone('0917123456789999'), isNotNull);
      expect(validatePhone(''), isNull);
      expect(validatePhone('', required: true), isNotNull);
    });

    test('promo codes and discounts', () {
      expect(validatePromoCode('welcome10'), isNull);
      expect(validatePromoCode('AB'), isNotNull);
      expect(validatePromoCode('HAS SPACE'), isNotNull);
      expect(validatePromoCode('PUTANGINA'), isNotNull);
      expect(validateDiscount('100', 'percent'), isNull);
      expect(validateDiscount('101', 'percent'), isNotNull);
      expect(validateDiscount('0', 'percent'), isNotNull);
      expect(validateDiscount('-5', 'fixed'), isNotNull);
    });

    test('spam text', () {
      expect(validateText('aaaaaaaaaaaa', max: 200), isNotNull);
      expect(validateText('!!!!!!!!!!!!', max: 200), isNotNull);
      expect(validateText('No onions please', max: 200), isNull);
      expect(validateText('x' * 201, max: 200), isNotNull);
    });
  });
}

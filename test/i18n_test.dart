import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/core/i18n.dart';

void main() {
  tearDown(() => Lang.fil = false);

  test('English passes through and fills placeholders', () {
    expect(tr('Your cart'), 'Your cart');
    expect(tr('Order {n}', {'n': 'FR-1'}), 'Order FR-1');
  });

  test('Filipino translates, falls back to English when missing', () {
    Lang.fil = true;
    expect(tr('Your cart'), 'Cart mo');
    expect(tr('Only {n} left!', {'n': 3}), '3 na lang ang natitira!');
    expect(tr('Some untranslated text'), 'Some untranslated text');
  });
}

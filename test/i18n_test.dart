import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/core/i18n.dart';

Set<String> _placeholders(String s) =>
    RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

/// Every English literal passed to tr('…') / tr("…") in lib/.
Set<String> _sourceKeys() {
  final keys = <String>{};
  final single = RegExp(r"tr\(\s*'((?:[^'\\]|\\.)*)'(?:\s*'((?:[^'\\]|\\.)*)')?");
  final double = RegExp(r'tr\(\s*"([^"]*)"');
  String unescape(String s) =>
      s.replaceAll(r"\'", "'").replaceAll(r'\n', '\n');
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('l10n')) continue;
    // Skip doc comments (they show tr() usage examples).
    final src = f
        .readAsLinesSync()
        .where((l) => !l.trimLeft().startsWith('///'))
        .join('\n');
    for (final m in single.allMatches(src)) {
      keys.add(unescape(m.group(1)! + (m.group(2) ?? '')));
    }
    for (final m in double.allMatches(src)) {
      keys.add(m.group(1)!);
    }
  }
  return keys;
}

void main() {
  tearDown(() => Lang.current = kLanguages.first);

  final reference = languageFor('fil').strings;

  test('English passes through and fills placeholders', () {
    expect(tr('Your cart'), 'Your cart');
    expect(tr('Order {n}', {'n': 'FR-1'}), 'Order FR-1');
  });

  test('a chosen language translates and falls back to English', () {
    Lang.current = languageFor('es');
    expect(tr('Your cart'), 'Tu carrito');
    expect(tr('Only {n} left!', {'n': 3}), '¡Solo quedan 3!');
    expect(tr('Some untranslated text'), 'Some untranslated text');
  });

  test('unknown codes fall back to English', () {
    expect(languageFor('xx').code, 'en');
    expect(languageFor(null).code, 'en');
  });

  test('language codes are unique', () {
    final codes = kLanguages.map((l) => l.code).toList();
    expect(codes.toSet().length, codes.length);
  });

  for (final lang in kLanguages.where((l) => l.code != 'en')) {
    group(lang.englishName, () {
      test('covers every phrase, with no stray keys', () {
        final missing = reference.keys.toSet().difference(lang.strings.keys.toSet());
        final extra = lang.strings.keys.toSet().difference(reference.keys.toSet());
        expect(missing, isEmpty, reason: 'untranslated');
        expect(extra, isEmpty, reason: 'keys that match no English text');
      });

      test('keeps every {placeholder}', () {
        for (final e in lang.strings.entries) {
          expect(_placeholders(e.value), _placeholders(e.key),
              reason: '"${e.key}" → "${e.value}"');
        }
      });
    });
  }

  test('every tr() phrase in the app is translated', () {
    final missing = _sourceKeys().difference(reference.keys.toSet());
    expect(missing, isEmpty);
  });
}

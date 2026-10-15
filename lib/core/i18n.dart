/// App languages for the student-facing screens.
///
/// `tr('English text')` returns the text in the chosen language, falling
/// back to English for anything not translated yet. Values go in
/// `{placeholders}`: `tr('Order {n}', {'n': number})`.
///
/// To add a language: create lib/core/l10n/<code>.dart with a map keyed by
/// the English strings (copy fil.dart as a template), then add one
/// [AppLanguage] line to [kLanguages]. test/i18n_test.dart checks that
/// every translation keeps the same {placeholders} as its English key.
/// Stall/admin screens and the privacy notice stay English.
library;

import 'dart:ui' show PlatformDispatcher;

import 'l10n/ceb.dart' as ceb;
import 'l10n/es.dart' as es;
import 'l10n/fil.dart' as fil;
import 'l10n/ja.dart' as ja;
import 'l10n/ko.dart' as ko;
import 'l10n/zh.dart' as zh;

class AppLanguage {
  /// BCP-47 code, also what is saved in the browser.
  final String code;

  /// The language's name in that language ("Español"), shown in pickers.
  final String nativeName;

  /// The English name ("Spanish"), shown as a hint under [nativeName].
  final String englishName;

  final Map<String, String> strings;

  const AppLanguage(this.code, this.nativeName, this.englishName, this.strings);
}

const kLanguages = <AppLanguage>[
  AppLanguage('en', 'English', 'English', {}),
  AppLanguage('fil', 'Filipino', 'Filipino', fil.fil),
  AppLanguage('ceb', 'Bisaya', 'Cebuano', ceb.ceb),
  AppLanguage('es', 'Español', 'Spanish', es.es),
  AppLanguage('zh', '中文', 'Chinese (Simplified)', zh.zh),
  AppLanguage('ko', '한국어', 'Korean', ko.ko),
  AppLanguage('ja', '日本語', 'Japanese', ja.ja),
];

AppLanguage languageFor(String? code) => kLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => kLanguages.first,
    );

/// The device's language if we support it, else English. Used the first
/// time someone opens the app (before they pick one themselves).
String deviceLanguageCode() {
  for (final locale in PlatformDispatcher.instance.locales) {
    final lang = locale.languageCode.toLowerCase();
    // Tagalog devices report "tl"; Filipino is the same language here.
    final code = lang == 'tl' ? 'fil' : lang;
    if (kLanguages.any((l) => l.code == code)) return code;
  }
  return 'en';
}

abstract final class Lang {
  /// Set by FoodRushApp from the saved language before building.
  static AppLanguage current = kLanguages.first;

  static String get code => current.code;
}

String tr(String en, [Map<String, Object?> args = const {}]) {
  var s = Lang.current.strings[en] ?? en;
  for (final e in args.entries) {
    s = s.replaceAll('{${e.key}}', '${e.value}');
  }
  return s;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../shared/browser/browser.dart' as browser;

/// Light / dark / follow-the-device, remembered per browser.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() =>
      // No choice saved yet: the admin's default for new visitors.
      switch (browser.readPref(_key) ?? Brand.current.defaultTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  void set(ThemeMode mode) {
    state = mode;
    browser.writePref(_key, mode.name);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// The app language (an [AppLanguage] code), remembered per browser. The
/// first visit follows the device language when we support it.
class LanguageController extends Notifier<String> {
  static const _key = 'lang';

  @override
  String build() {
    final saved = browser.readPref(_key);
    if (saved != null && kLanguages.any((l) => l.code == saved)) return saved;
    return deviceLanguageCode();
  }

  void set(String code) {
    state = code;
    browser.writePref(_key, code);
  }
}

final languageProvider =
    NotifierProvider<LanguageController, String>(LanguageController.new);

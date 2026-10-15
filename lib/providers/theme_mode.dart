import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/browser/browser.dart' as browser;

/// Light / dark / follow-the-device, remembered per browser.
class ThemeModeController extends Notifier<ThemeMode> {
  static const _key = 'themeMode';

  @override
  ThemeMode build() => switch (browser.readPref(_key)) {
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

/// English or Filipino for the student screens, remembered per browser.
/// true = Filipino.
class FilipinoController extends Notifier<bool> {
  static const _key = 'lang';

  @override
  bool build() => browser.readPref(_key) == 'fil';

  void set(bool fil) {
    state = fil;
    browser.writePref(_key, fil ? 'fil' : 'en');
  }
}

final filipinoProvider =
    NotifierProvider<FilipinoController, bool>(FilipinoController.new);

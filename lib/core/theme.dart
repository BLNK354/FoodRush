import 'package:flutter/material.dart';

/// FoodRush design tokens + Material 3 theme.
abstract final class FrColors {
  /// Set by FoodRushApp from the resolved light/dark mode before it builds
  /// (and every widget is rebuilt when it flips). Neutrals and status
  /// colors below read it; brand colors are the same in both modes.
  static bool dark = false;

  static const Color primary = Color(0xFFE23744); // foodpanda-esque red
  static const Color primaryDark = Color(0xFFB02A34);
  static const Color secondary = Color(0xFFFF8A00); // hungry orange

  // Neutrals. Dark steps are their own warm greys (not an inverted light
  // palette); muted text clears 4.5:1 on its own mode's background.
  static Color get cream => dark ? const Color(0xFF171412) : const Color(0xFFFFF8F0);
  static Color get surface => dark ? const Color(0xFF231F1D) : Colors.white;
  static Color get ink => dark ? const Color(0xFFF4EFEA) : const Color(0xFF231F20);
  static Color get muted => dark ? const Color(0xFFADA59F) : const Color(0xFF6E6864);
  static Color get line => dark ? const Color(0xFF3A3431) : const Color(0xFFEDE4DC);

  // Status colors: lighter steps in dark mode so they stay legible as text.
  static Color get success => dark ? const Color(0xFF4CC274) : const Color(0xFF15803D);
  static Color get warning => dark ? const Color(0xFFF2C14E) : const Color(0xFF946A00);
  static Color get danger => dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);
  static Color get info => dark ? const Color(0xFF6CB2FF) : const Color(0xFF1976D2);

  static Color get chipCash => dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
  static Color get chipGcash => dark ? const Color(0xFF6FA8FF) : const Color(0xFF0057E4);
}

abstract final class FrRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

abstract final class FrSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// The app theme for the current [FrColors.dark] mode.
ThemeData buildFrTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: FrColors.primary,
    brightness: FrColors.dark ? Brightness.dark : Brightness.light,
    primary: FrColors.primary,
    onPrimary: Colors.white,
    secondary: FrColors.secondary,
    surface: FrColors.surface,
    onSurface: FrColors.ink,
    error: FrColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: FrColors.cream,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: FrColors.surface,
      foregroundColor: FrColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: FrColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: FrColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.lg),
        side: BorderSide(color: FrColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FrColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: BorderSide(color: FrColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: BorderSide(color: FrColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: const BorderSide(color: FrColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: BorderSide(color: FrColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: BorderSide(color: FrColors.danger, width: 1.6),
      ),
      hintStyle: TextStyle(color: FrColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FrColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FrColors.primary,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: FrColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrRadius.md),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FrColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.sm),
        side: BorderSide(color: FrColors.line),
      ),
      backgroundColor: FrColors.surface,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: FrColors.ink,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FrColors.dark ? const Color(0xFF3A3431) : FrColors.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor: FrColors.dark ? const Color(0xFFFF8A8A) : null,
    ),
    dividerTheme: DividerThemeData(color: FrColors.line, thickness: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: FrColors.surface,
      indicatorColor: FrColors.primary.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: FrColors.primary),
      selectedLabelTextStyle: const TextStyle(
        color: FrColors.primary,
        fontWeight: FontWeight.w800,
      ),
      unselectedIconTheme: IconThemeData(color: FrColors.muted),
      unselectedLabelTextStyle: TextStyle(color: FrColors.muted),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FrColors.surface,
        foregroundColor: FrColors.ink,
        elevation: 0,
        side: BorderSide(color: FrColors.line),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FrColors.primary,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: FrColors.primary,
      unselectedLabelColor: FrColors.muted,
      indicatorColor: FrColors.primary,
      labelStyle: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

import 'package:flutter/material.dart';

/// FoodRush design tokens + Material 3 theme.
abstract final class FrColors {
  static const Color primary = Color(0xFFE23744); // foodpanda-esque red
  static const Color primaryDark = Color(0xFFB02A34);
  static const Color secondary = Color(0xFFFF8A00); // hungry orange
  static const Color cream = Color(0xFFFFF8F0);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF231F20);
  static const Color muted = Color(0xFF7A7470);
  static const Color line = Color(0xFFEDE4DC);

  static const Color success = Color(0xFF1B9E4B);
  static const Color warning = Color(0xFFE6A700);
  static const Color danger = Color(0xFFD32F2F);
  static const Color info = Color(0xFF1976D2);

  static const Color chipCash = Color(0xFF2E7D32);
  static const Color chipGcash = Color(0xFF0057E4);
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

ThemeData buildFrTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: FrColors.primary,
    primary: FrColors.primary,
    secondary: FrColors.secondary,
    surface: FrColors.surface,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: FrColors.cream,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
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
        side: const BorderSide(color: FrColors.line),
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
        borderSide: const BorderSide(color: FrColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: const BorderSide(color: FrColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: const BorderSide(color: FrColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: const BorderSide(color: FrColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: const BorderSide(color: FrColors.danger, width: 1.6),
      ),
      hintStyle: const TextStyle(color: FrColors.muted),
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
        side: const BorderSide(color: FrColors.line),
      ),
      backgroundColor: FrColors.surface,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: FrColors.ink,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FrColors.ink,
      contentTextStyle: TextStyle(color: Colors.white),
    ),
    dividerTheme: const DividerThemeData(color: FrColors.line, thickness: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: FrColors.surface,
      indicatorColor: FrColors.primary.withValues(alpha: 0.12),
      selectedIconTheme: const IconThemeData(color: FrColors.primary),
      selectedLabelTextStyle: const TextStyle(
        color: FrColors.primary,
        fontWeight: FontWeight.w800,
      ),
      unselectedIconTheme: const IconThemeData(color: FrColors.muted),
      unselectedLabelTextStyle: const TextStyle(color: FrColors.muted),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FrColors.surface,
        foregroundColor: FrColors.ink,
        elevation: 0,
        side: const BorderSide(color: FrColors.line),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: FrColors.primary,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: FrColors.primary,
      unselectedLabelColor: FrColors.muted,
      indicatorColor: FrColors.primary,
      labelStyle: TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

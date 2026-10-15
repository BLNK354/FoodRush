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
  static Color get cream => dark ? const Color(0xFF0F0D0C) : const Color(0xFFFBF7F3);
  static Color get surface => dark ? const Color(0xFF1A1716) : Colors.white;
  static Color get surfaceAlt => dark ? const Color(0xFF231F1D) : const Color(0xFFF5EFEA);
  static Color get ink => dark ? const Color(0xFFF6F1EC) : const Color(0xFF1A1614);
  static Color get muted => dark ? const Color(0xFFADA59F) : const Color(0xFF6E6864);
  static Color get line => dark ? const Color(0xFF332D2A) : const Color(0xFFEDE4DC);

  /// Barely-there edge for elevated and glass surfaces.
  static Color get hairline => dark
      ? Colors.white.withValues(alpha: 0.07)
      : const Color(0xFF3A1F14).withValues(alpha: 0.07);

  /// Translucent fill behind frosted glass.
  static Color get glass => dark
      ? const Color(0xFF1A1716).withValues(alpha: 0.72)
      : Colors.white.withValues(alpha: 0.74);

  // Status colors: lighter steps in dark mode so they stay legible as text.
  static Color get success => dark ? const Color(0xFF4CC274) : const Color(0xFF15803D);
  static Color get warning => dark ? const Color(0xFFF2C14E) : const Color(0xFF946A00);
  static Color get danger => dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);
  static Color get info => dark ? const Color(0xFF6CB2FF) : const Color(0xFF1976D2);

  static Color get chipCash => dark ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
  static Color get chipGcash => dark ? const Color(0xFF6FA8FF) : const Color(0xFF0057E4);
}

abstract final class FrGradients {
  /// Ember: the brand red warming into coral.
  static const LinearGradient brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B4A), FrColors.primary, Color(0xFFC81E4A)],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB547), Color(0xFFFF6B4A), FrColors.primary],
  );

  static LinearGradient get hero => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: FrColors.dark
            ? const [Color(0xFF3A1414), Color(0xFF2A1210), Color(0xFF1A1716)]
            : const [Color(0xFFFFE8DE), Color(0xFFFFF1E6), Color(0xFFFFFAF5)],
      );
}

/// Layered shadows: a tight contact shadow plus a wide ambient one.
abstract final class FrShadows {
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: const Color(0xFF3A1F14)
              .withValues(alpha: FrColors.dark ? 0.35 : 0.05),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: const Color(0xFF3A1F14)
              .withValues(alpha: FrColors.dark ? 0.4 : 0.07),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  static List<BoxShadow> get raised => [
        BoxShadow(
          color: const Color(0xFF3A1F14)
              .withValues(alpha: FrColors.dark ? 0.4 : 0.06),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: FrColors.primary.withValues(alpha: FrColors.dark ? 0.18 : 0.12),
          blurRadius: 40,
          offset: const Offset(0, 22),
        ),
      ];
}

abstract final class FrRadius {
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
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
  ).copyWith(surfaceTint: Colors.transparent);

  final base = ThemeData(
    useMaterial3: true,
    brightness: colorScheme.brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: FrColors.cream,
    fontFamily: 'PlusJakartaSans',
    splashFactory: InkSparkle.splashFactory,
  );

  // Plus Jakarta Sans (bundled): geometric, warm, reads premium at every
  // weight. Headlines get tight tracking.
  const family = 'PlusJakartaSans';
  final text = base.textTheme
      .apply(
        fontFamily: family,
        bodyColor: FrColors.ink,
        displayColor: FrColors.ink,
      )
      .copyWith(
        headlineLarge: TextStyle(
            fontFamily: family,
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            color: FrColors.ink),
        headlineMedium: TextStyle(
            fontFamily: family,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            color: FrColors.ink),
        headlineSmall: TextStyle(
            fontFamily: family,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
            color: FrColors.ink),
      );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
        borderSide: BorderSide(color: c, width: w),
      );

  final pageTransitions = PageTransitionsTheme(builders: {
    for (final p in TargetPlatform.values)
      p: const FadeForwardsPageTransitionsBuilder(),
  });

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: text,
    pageTransitionsTheme: pageTransitions,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: FrColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: family,
        color: FrColors.ink,
        fontSize: 19,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    cardTheme: CardThemeData(
      color: FrColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.xl),
        side: BorderSide(color: FrColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FrColors.surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(FrColors.primary, 1.6),
      errorBorder: border(FrColors.danger),
      focusedErrorBorder: border(FrColors.danger, 1.6),
      hintStyle: TextStyle(color: FrColors.muted),
      labelStyle: TextStyle(color: FrColors.muted),
      floatingLabelStyle: const TextStyle(
          color: FrColors.primary, fontWeight: FontWeight.w700),
      prefixIconColor: FrColors.muted,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FrColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrRadius.lg),
        ),
        textStyle: TextStyle(
            fontFamily: family, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FrColors.ink,
        minimumSize: const Size(48, 50),
        side: BorderSide(color: FrColors.line, width: 1.2),
        backgroundColor: FrColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrRadius.lg),
        ),
        textStyle: TextStyle(
            fontFamily: family, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: FrColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FrRadius.md),
        ),
        textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: FrColors.line),
      ),
      backgroundColor: FrColors.surface,
      selectedColor: FrColors.primary.withValues(alpha: 0.12),
      checkmarkColor: FrColors.primary,
      labelStyle: TextStyle(
        fontFamily: family,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: FrColors.ink,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: FrColors.primary.withValues(alpha: 0.12),
        selectedForegroundColor: FrColors.primary,
        side: BorderSide(color: FrColors.line),
        textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w700),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: FrColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.xl),
      ),
      titleTextStyle: TextStyle(
        fontFamily: family,
        color: FrColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: FrColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(FrRadius.xl)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: FrColors.dark ? const Color(0xFF2C2624) : FrColors.ink,
      contentTextStyle: TextStyle(
          fontFamily: family, color: Colors.white, fontWeight: FontWeight.w600),
      actionTextColor: FrColors.dark ? const Color(0xFFFF8A8A) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
      ),
      elevation: 6,
    ),
    dividerTheme: DividerThemeData(color: FrColors.line, thickness: 1),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: FrColors.surface,
      indicatorColor: FrColors.primary.withValues(alpha: 0.12),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FrRadius.md),
      ),
      selectedIconTheme: const IconThemeData(color: FrColors.primary),
      selectedLabelTextStyle: TextStyle(
        fontFamily: family,
        color: FrColors.primary,
        fontWeight: FontWeight.w800,
      ),
      unselectedIconTheme: IconThemeData(color: FrColors.muted),
      unselectedLabelTextStyle:
          TextStyle(fontFamily: family, color: FrColors.muted),
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
      dividerColor: Colors.transparent,
      labelStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w800),
      unselectedLabelStyle:
          TextStyle(fontFamily: family, fontWeight: FontWeight.w600),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: FrColors.dark ? const Color(0xFF2C2624) : FrColors.ink,
        borderRadius: BorderRadius.circular(FrRadius.sm),
      ),
      textStyle:
          TextStyle(fontFamily: family, color: Colors.white, fontSize: 12),
    ),
  );
}

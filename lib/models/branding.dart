import 'dart:convert';

import 'package:flutter/painting.dart';

/// The app's look, edited by admins in Content → Branding and stored in
/// Firestore at settings/branding (world-readable so even the signed-out
/// login screen follows it). Every field has a default, so a missing or
/// partial document still renders the stock FoodRush look.
class Branding {
  static const defaultPrimary = Color(0xFFE23744);
  static const defaultAccent = Color(0xFFFF8A00);

  /// Corner styles and fonts the admin can pick (keep in sync with rules).
  static const corners = ['rounded', 'soft', 'sharp'];
  static const fonts = ['modern', 'classic'];
  static const themes = ['system', 'light', 'dark'];

  final String appName;
  final String tagline; // '' = the built-in, translated tagline
  final Color primary;
  final Color accent;
  final String? logo; // data URL, square
  final String? loginImage; // data URL, behind sign-in screens
  final String? heroImage; // data URL, behind the Shop greeting
  final String corner;
  final String font;
  final bool effects3d;
  final bool animatedBackground;
  final String defaultTheme;

  const Branding({
    this.appName = 'FoodRush',
    this.tagline = '',
    this.primary = defaultPrimary,
    this.accent = defaultAccent,
    this.logo,
    this.loginImage,
    this.heroImage,
    this.corner = 'rounded',
    this.font = 'modern',
    this.effects3d = true,
    this.animatedBackground = true,
    this.defaultTheme = 'system',
  });

  static const defaults = Branding();

  /// Multiplier applied to the app's corner radii.
  double get radiusScale => switch (corner) {
        'soft' => 0.6,
        'sharp' => 0.2,
        _ => 1.0,
      };

  static String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static Color? parseHex(String? s) {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch((s ?? '').trim());
    return m == null ? null : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }

  factory Branding.fromMap(Map<String, dynamic>? m) {
    if (m == null) return defaults;
    String? img(Object? v) => v is String && v.startsWith('data:image/') ? v : null;
    String pick(Object? v, List<String> allowed, String fallback) =>
        v is String && allowed.contains(v) ? v : fallback;
    final name = (m['appName'] as String?)?.trim() ?? '';
    return Branding(
      appName: name.isEmpty ? defaults.appName : name,
      tagline: (m['tagline'] as String?)?.trim() ?? '',
      primary: parseHex(m['primary'] as String?) ?? defaultPrimary,
      accent: parseHex(m['accent'] as String?) ?? defaultAccent,
      logo: img(m['logo']),
      loginImage: img(m['loginImage']),
      heroImage: img(m['heroImage']),
      corner: pick(m['corner'], corners, 'rounded'),
      font: pick(m['font'], fonts, 'modern'),
      effects3d: m['effects3d'] is bool ? m['effects3d'] as bool : true,
      animatedBackground:
          m['animatedBackground'] is bool ? m['animatedBackground'] as bool : true,
      defaultTheme: pick(m['defaultTheme'], themes, 'system'),
    );
  }

  Map<String, dynamic> toMap() => {
        'appName': appName,
        'tagline': tagline,
        'primary': hex(primary),
        'accent': hex(accent),
        'logo': logo,
        'loginImage': loginImage,
        'heroImage': heroImage,
        'corner': corner,
        'font': font,
        'effects3d': effects3d,
        'animatedBackground': animatedBackground,
        'defaultTheme': defaultTheme,
      };

  String toJson() => jsonEncode(toMap());

  static Branding? fromJson(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return Branding.fromMap(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Branding copyWith({
    String? appName,
    String? tagline,
    Color? primary,
    Color? accent,
    String? Function()? logo,
    String? Function()? loginImage,
    String? Function()? heroImage,
    String? corner,
    String? font,
    bool? effects3d,
    bool? animatedBackground,
    String? defaultTheme,
  }) =>
      Branding(
        appName: appName ?? this.appName,
        tagline: tagline ?? this.tagline,
        primary: primary ?? this.primary,
        accent: accent ?? this.accent,
        logo: logo != null ? logo() : this.logo,
        loginImage: loginImage != null ? loginImage() : this.loginImage,
        heroImage: heroImage != null ? heroImage() : this.heroImage,
        corner: corner ?? this.corner,
        font: font ?? this.font,
        effects3d: effects3d ?? this.effects3d,
        animatedBackground: animatedBackground ?? this.animatedBackground,
        defaultTheme: defaultTheme ?? this.defaultTheme,
      );

  @override
  bool operator ==(Object other) =>
      other is Branding && other.toJson() == toJson();

  @override
  int get hashCode => toJson().hashCode;
}

/// Ready-made colour pairs for the Branding editor.
class BrandPalette {
  final String name;
  final Color primary;
  final Color accent;
  const BrandPalette(this.name, this.primary, this.accent);

  static const all = [
    BrandPalette('Ember', Color(0xFFE23744), Color(0xFFFF8A00)),
    BrandPalette('LPU Maroon', Color(0xFF8B1E2D), Color(0xFFD4A017)),
    BrandPalette('Ocean', Color(0xFF1565C0), Color(0xFF00ACC1)),
    BrandPalette('Forest', Color(0xFF2E7D32), Color(0xFF9CCC65)),
    BrandPalette('Royal', Color(0xFF5E35B1), Color(0xFFEC407A)),
    BrandPalette('Sunset', Color(0xFFD81B60), Color(0xFFFFA726)),
    BrandPalette('Teal', Color(0xFF00796B), Color(0xFFFFB300)),
    BrandPalette('Midnight', Color(0xFF263238), Color(0xFFFF7043)),
  ];
}

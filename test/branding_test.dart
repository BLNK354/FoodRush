import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/models/branding.dart';

void main() {
  test('a missing document is the stock look', () {
    expect(Branding.fromMap(null), Branding.defaults);
    expect(Branding.fromMap({}).appName, 'FoodRush');
  });

  test('hex colours round-trip', () {
    expect(Branding.hex(const Color(0xFF1565C0)), '#1565C0');
    expect(Branding.parseHex('#1565c0'), const Color(0xFF1565C0));
    expect(Branding.parseHex('1565C0'), const Color(0xFF1565C0));
    expect(Branding.parseHex('blue'), isNull);
  });

  test('saving and loading keeps every field', () {
    const b = Branding(
      appName: 'CampusEats',
      tagline: 'Fast food, faster',
      primary: Color(0xFF2E7D32),
      accent: Color(0xFF9CCC65),
      logo: 'data:image/jpeg;base64,AAAA',
      corner: 'sharp',
      font: 'classic',
      effects3d: false,
      animatedBackground: false,
      defaultTheme: 'dark',
    );
    expect(Branding.fromMap(b.toMap()), b);
    expect(Branding.fromJson(b.toJson()), b);
  });

  test('junk values fall back to safe defaults', () {
    final b = Branding.fromMap({
      'appName': '   ',
      'primary': 'red',
      'corner': 'blob',
      'logo': 'https://evil.example/x.png',
      'effects3d': 'yes',
    });
    expect(b.appName, 'FoodRush');
    expect(b.primary, Branding.defaultPrimary);
    expect(b.corner, 'rounded');
    expect(b.logo, isNull);
    expect(b.effects3d, isTrue);
  });

  test('corner styles scale the radii', () {
    expect(const Branding(corner: 'rounded').radiusScale, 1.0);
    expect(const Branding(corner: 'sharp').radiusScale, lessThan(0.5));
  });
}

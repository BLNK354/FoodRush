import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';

enum PasswordStrength { weak, fair, good, strong }

/// Rates [pw] and suggests the single most useful improvement (null when
/// there is nothing left to suggest). Length matters most; common or
/// repetitive passwords are always weak.
(PasswordStrength, String?) ratePassword(String pw) {
  final lower = pw.toLowerCase();
  const common = [
    'password', 'passw0rd', '12345678', '123456789', '1234567890',
    'qwerty', 'qwertyuiop', 'iloveyou', 'abc12345', 'foodrush', 'lpu12345',
    '11111111', '00000000', 'letmein', 'welcome',
  ];
  final hasLower = RegExp('[a-z]').hasMatch(pw);
  final hasUpper = RegExp('[A-Z]').hasMatch(pw);
  final hasDigit = RegExp(r'\d').hasMatch(pw);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(pw);
  final oneChar = pw.isNotEmpty && pw.split('').toSet().length <= 2;

  if (pw.length < 8) return (PasswordStrength.weak, 'Use at least 8 characters');
  if (oneChar || common.any(lower.contains)) {
    return (PasswordStrength.weak, 'Avoid common or repeated passwords');
  }

  var score = 0;
  if (pw.length >= 12) score++;
  if (pw.length >= 16) score++;
  if (hasLower && hasUpper) score++;
  if (hasDigit) score++;
  if (hasSymbol) score++;

  final level = score <= 1
      ? PasswordStrength.weak
      : score == 2
          ? PasswordStrength.fair
          : score == 3
              ? PasswordStrength.good
              : PasswordStrength.strong;

  String? tip;
  if (pw.length < 12) {
    tip = 'Use 12 or more characters';
  } else if (!(hasLower && hasUpper)) {
    tip = 'Mix upper and lower case';
  } else if (!hasDigit) {
    tip = 'Add a number';
  } else if (!hasSymbol) {
    tip = 'Add a symbol like ! or #';
  }
  return (level, level == PasswordStrength.strong ? null : tip);
}

/// Live, animated strength bar for a password field.
class PasswordStrengthMeter extends StatelessWidget {
  final TextEditingController controller;
  const PasswordStrengthMeter({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final pw = value.text;
        final (level, tip) = ratePassword(pw);
        final (label, color) = switch (level) {
          PasswordStrength.weak => (tr('Weak'), FrColors.danger),
          PasswordStrength.fair => (tr('Fair'), FrColors.warning),
          PasswordStrength.good => (tr('Good'), FrColors.info),
          PasswordStrength.strong => (tr('Strong'), FrColors.success),
        };
        final filled = pw.isEmpty ? 0 : level.index + 1;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: pw.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    label: tr('Password strength: {level}', {'level': label}),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var i = 0; i < 4; i++) ...[
                              if (i > 0) const SizedBox(width: 5),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutCubic,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: i < filled
                                        ? color
                                        : FrColors.muted
                                            .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: i == filled - 1
                                        ? [
                                            BoxShadow(
                                              color: color
                                                  .withValues(alpha: 0.45),
                                              blurRadius: 8,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontFamily: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.fontFamily,
                                color: color,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                              child: Text(label),
                            ),
                            if (tip != null) ...[
                              Text('  ·  ',
                                  style: TextStyle(
                                      color: FrColors.muted, fontSize: 12.5)),
                              Expanded(
                                child: Text(tr(tip),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: FrColors.muted,
                                        fontSize: 12.5)),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

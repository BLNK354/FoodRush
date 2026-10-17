import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import '../providers/theme_mode.dart';

/// Bottom sheet listing every app language by its own name.
Future<void> showLanguagePicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(languageProvider);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(tr('Language'),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final l in kLanguages)
                    _LanguageTile(
                      language: l,
                      selected: l.code == current,
                      onTap: () {
                        ref.read(languageProvider.notifier).set(l.code);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;
  const _LanguageTile(
      {required this.language, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? FrColors.primary.withValues(alpha: 0.1)
            : FrColors.surfaceAlt,
        borderRadius: BorderRadius.circular(FrRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(FrRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FrRadius.lg),
              border: Border.all(
                color: selected ? FrColors.primary : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(language.nativeName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      if (language.englishName != language.nativeName)
                        Text(language.englishName,
                            style: TextStyle(
                                fontSize: 12.5, color: FrColors.muted)),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: selected
                      ? Container(
                          key: const ValueKey('on'),
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: FrGradients.brand,
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 16, color: Colors.white),
                        )
                      : const SizedBox(key: ValueKey('off'), width: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact "🌐 English ▾" button that opens [showLanguagePicker].
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = languageFor(ref.watch(languageProvider));
    return TextButton.icon(
      onPressed: () => showLanguagePicker(context, ref),
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lang.nativeName),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }
}

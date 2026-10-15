import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/theme.dart';
import 'browser/browser.dart' as browser;

/// "Install FoodRush" card: a real install prompt on Chrome/Edge/Android,
/// "Share → Add to Home Screen" steps on iPhone. Hidden once installed, when
/// the browser can't install, or after "Not now" (remembered per browser).
class InstallAppCard extends StatefulWidget {
  const InstallAppCard({super.key});

  @override
  State<InstallAppCard> createState() => _InstallAppCardState();
}

class _InstallAppCardState extends State<InstallAppCard> {
  static const _dismissKey = 'installCardDismissed';
  bool _hidden = browser.readPref(_dismissKey) == '1';

  bool get _shouldShow =>
      !_hidden &&
      !browser.isInstalledApp &&
      (browser.canPromptInstall || browser.isIos);

  Future<void> _install() async {
    if (browser.isIos) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Add FoodRush to your Home Screen'),
          content: const Text(
              '1. Tap the Share button in Safari (square with an arrow).\n'
              '2. Choose "Add to Home Screen".\n'
              '3. Tap "Add". FoodRush then opens like an app.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr('Got it'))),
          ],
        ),
      );
      return;
    }
    final ok = await browser.promptInstall();
    if (mounted) setState(() => _hidden = ok || !browser.canPromptInstall);
  }

  void _dismiss() {
    browser.writePref(_dismissKey, '1');
    setState(() => _hidden = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            const Icon(Icons.install_mobile, color: FrColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(tr('Install FoodRush for one-tap ordering from your home screen.'),
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            TextButton(onPressed: _dismiss, child: Text(tr('Not now'))),
            FilledButton(onPressed: _install, child: Text(tr('Install'))),
          ],
        ),
      ),
    );
  }
}

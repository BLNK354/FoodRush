import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/widgets.dart';

/// Shown to signed-in accounts whose email isn't confirmed yet. Checks every
/// few seconds, so clicking the link (even on another device) moves the app
/// on by itself; the router leaves this screen once verified.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _resendCooldown = 60;
  Timer? _poll;
  Timer? _tick;
  int _wait = _resendCooldown; // a link was just sent at sign-up
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _check(quiet: true));
    _startCooldown();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _tick?.cancel();
    setState(() => _wait = _resendCooldown);
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _wait = _wait > 0 ? _wait - 1 : 0);
      if (_wait == 0) t.cancel();
    });
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final ok =
          await ref.read(authControllerProvider.notifier).refreshEmailVerified();
      if (!ok && !quiet && mounted) {
        showSnack(context, tr('Not verified yet. Click the link in the email first.'),
            error: true);
      }
    } catch (_) {
      // offline: the next poll tries again
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    final err =
        await ref.read(authControllerProvider.notifier).resendVerification();
    if (!mounted) return;
    showSnack(context, err ?? 'Sent! Check your inbox (and spam folder).',
        error: err != null);
    if (err == null) _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.mark_email_unread_outlined,
                        size: 56, color: FrColors.primary),
                    const SizedBox(height: 16),
                    Text(tr('Verify your email'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      tr('We sent a link to {email}. Open it to confirm this is '
                          'your inbox, then come back here.', {'email': email}),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: FrColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(tr('This page continues by itself once you click the link.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: FrColors.muted, fontSize: 12.5)),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _check(),
                      child: Text(tr("I've verified — continue")),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: _wait > 0 ? null : _resend,
                      child: Text(_wait > 0
                          ? tr('Resend email ({s}s)', {'s': _wait})
                          : tr('Resend email')),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () =>
                          ref.read(authControllerProvider.notifier).signOut(),
                      child: Text(tr('Use a different account')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

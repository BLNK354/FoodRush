import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/premium.dart';
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
  int _wait = 0;
  bool _checking = false;
  bool _sending = false;
  DateTime? _sentAt;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(quiet: true),
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _sentAt = uid == null ? null : AuthController.verificationSentAt(uid);
    if (_sentAt == null) {
      // Never sent from this browser (e.g. an account made before
      // verification existed): send one now instead of waiting.
      WidgetsBinding.instance.addPostFrameCallback((_) => _resend(auto: true));
    } else {
      final left =
          _resendCooldown - DateTime.now().difference(_sentAt!).inSeconds;
      if (left > 0) _startCooldown(left);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = _resendCooldown]) {
    _tick?.cancel();
    setState(() => _wait = seconds);
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
      final ok = await ref
          .read(authControllerProvider.notifier)
          .refreshEmailVerified();
      if (!ok && !quiet && mounted) {
        showSnack(
          context,
          tr('Not verified yet. Click the link in the email first.'),
          error: true,
        );
      }
    } catch (_) {
      // offline: the next poll tries again
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend({bool auto = false}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final err = await ref
        .read(authControllerProvider.notifier)
        .resendVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendError = err;
      if (err == null) _sentAt = DateTime.now();
    });
    if (err == null) {
      _startCooldown();
      if (!auto) showSnack(context, tr('Sent! Check your inbox (and spam folder).'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: FadeSlideIn(
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(FrRadius.xl + 4),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: ClayOrb(
                            icon: Icons.mark_email_unread_rounded,
                            size: 88,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          tr('Verify your email'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _sentAt == null
                              ? tr('Sending a link to {email}…',
                                  {'email': email})
                              : tr(
                                  'We sent a link to {email}. Open it to confirm this is '
                                  'your inbox, then come back here.',
                                  {'email': email},
                                ),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: FrColors.muted),
                        ),
                        const SizedBox(height: 14),
                        _SendStatus(
                          sending: _sending,
                          sentAt: _sentAt,
                          error: _sendError,
                          sender: 'noreply@${Firebase.app().options.authDomain ?? 'firebaseapp.com'}',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tr(
                            'This page continues by itself once you click the link.',
                          ),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: FrColors.muted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          onPressed: () => _check(),
                          icon: Icons.verified_rounded,
                          label: tr("I've verified — continue"),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _wait > 0 ? null : _resend,
                          child: Text(
                            _wait > 0
                                ? tr('Resend email ({s}s)', {'s': _wait})
                                : tr('Resend email'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .signOut(),
                          child: Text(tr('Use a different account')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the email stands: sending, sent at a time (with who it comes from,
/// so people know what to look for in Spam), or why sending failed.
class _SendStatus extends StatelessWidget {
  final bool sending;
  final DateTime? sentAt;
  final String? error;
  final String sender;
  const _SendStatus({
    required this.sending,
    required this.sentAt,
    required this.error,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = error != null
        ? (Icons.error_outline_rounded, FrColors.danger, error!)
        : sending
            ? (Icons.schedule_send_rounded, FrColors.info, tr('Sending…'))
            : sentAt != null
                ? (
                    Icons.mark_email_read_rounded,
                    FrColors.success,
                    tr('Sent at {time} from {sender}. Not in your inbox? Check Spam or Promotions.',
                        {'time': fmtClock(sentAt!), 'sender': sender}),
                  )
                : (Icons.schedule_send_rounded, FrColors.info, tr('Sending…'));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(FrRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    color: FrColors.ink, fontSize: 12.5, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

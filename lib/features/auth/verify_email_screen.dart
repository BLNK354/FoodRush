import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/premium.dart';
import '../../shared/widgets.dart';

/// Shown to signed-in accounts whose email isn't confirmed yet. Checks every
/// few seconds, so clicking the link (even on another device) moves the app
/// on by itself; the router leaves this screen once verified.
///
/// Shows when the current link expires ([kVerifyLinkLifetime]) and how many
/// emails are left this hour ([kVerifySendsPerHour]); both come from the
/// server-stamped verifyLinks record, so they agree across devices.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;
  Timer? _tick;
  bool _checking = false;
  bool _sending = false;
  bool _loaded = false;
  VerifyLinkInfo? _link;
  String? _sendError;
  DateTime _now = DateTime.now();

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _check(quiet: true),
    );
    // One clock drives the countdown and the resend gap.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load({bool autoSend = true}) async {
    VerifyLinkInfo? link;
    try {
      link = await AuthController.loadVerifyLink(_email);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _link = link;
      _loaded = true;
    });
    // Never sent (e.g. an account made before verification existed): send
    // one now instead of waiting for a link that never comes.
    if (autoSend && link == null) _send(auto: true);
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

  Future<void> _send({bool auto = false}) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final err =
        await ref.read(authControllerProvider.notifier).sendVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendError = err;
    });
    await _load(autoSend: false);
    if (err == null && !auto && mounted) {
      showSnack(context, tr('Sent! Check your inbox (and spam folder).'));
    }
  }

  /// Seconds until another email may be sent (0 = now).
  int get _gapLeft {
    final l = _link;
    if (l == null) return 0;
    final s = l.sentAt.add(kVerifyResendGap).difference(_now).inSeconds;
    return s > 0 ? s + 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final email = _email.isEmpty ? 'your email' : _email;
    final link = _link;
    final left = link?.sendsLeft(_now) ?? kVerifySendsPerHour;
    final canSend = !_sending && _gapLeft == 0 && left > 0;
    final sender =
        'noreply@${Firebase.app().options.authDomain ?? 'firebaseapp.com'}';

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
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          link == null
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
                        const SizedBox(height: 16),
                        if (_loaded && link != null && _sendError == null)
                          _LinkCountdown(link: link, now: _now),
                        const SizedBox(height: 10),
                        _SendStatus(
                          sending: _sending || !_loaded,
                          sentAt: link?.sentAt,
                          expired: link?.isExpired(_now) ?? false,
                          error: _sendError,
                          sender: sender,
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
                        const SizedBox(height: 22),
                        GradientButton(
                          onPressed: () => _check(),
                          icon: Icons.verified_rounded,
                          label: tr("I've verified — continue"),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: canSend ? _send : null,
                          icon: const Icon(Icons.forward_to_inbox_rounded),
                          label: Text(
                            _gapLeft > 0
                                ? tr('Resend email ({s}s)', {'s': _gapLeft})
                                : tr('Resend email'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _SendCounter(
                          sent: kVerifySendsPerHour - left,
                          resetsAt: link?.windowStart
                              .add(const Duration(hours: 1)),
                        ),
                        const SizedBox(height: 6),
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

/// "Link expires in 14:32" with a draining bar; turns amber in the last
/// two minutes and says when it has expired.
class _LinkCountdown extends StatelessWidget {
  final VerifyLinkInfo link;
  final DateTime now;
  const _LinkCountdown({required this.link, required this.now});

  @override
  Widget build(BuildContext context) {
    final total = kVerifyLinkLifetime.inSeconds;
    final left = link.expiresAt.difference(now).inSeconds.clamp(0, total);
    final expired = left == 0;
    final color = expired
        ? FrColors.danger
        : left <= 120
            ? FrColors.warning
            : FrColors.success;
    final mmss =
        '${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}';
    return Semantics(
      liveRegion: expired,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(expired ? Icons.timer_off_outlined : Icons.timer_outlined,
                  size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  expired
                      ? tr('This link has expired. Send a new one.')
                      : tr('Link expires in {time}', {'time': mmss}),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: left / total),
              duration: const Duration(milliseconds: 900),
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: color,
                backgroundColor: FrColors.muted.withValues(alpha: 0.16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Emails sent this hour: 2 of 5" as dots, with when the limit resets.
class _SendCounter extends StatelessWidget {
  final int sent;
  final DateTime? resetsAt;
  const _SendCounter({required this.sent, required this.resetsAt});

  @override
  Widget build(BuildContext context) {
    final full = sent >= kVerifySendsPerHour;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < kVerifySendsPerHour; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < sent
                      ? (full ? FrColors.danger : FrColors.primary)
                      : FrColors.muted.withValues(alpha: 0.25),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          full && resetsAt != null
              ? tr('Email limit reached. Try again after {time}.',
                  {'time': fmtClock(resetsAt!)})
              : tr('Emails sent this hour: {n} of {max}',
                  {'n': sent, 'max': kVerifySendsPerHour}),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: full ? FrColors.danger : FrColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Where the email stands: sending, sent at a time (with who it comes from,
/// so people know what to look for in Spam), or why sending failed.
class _SendStatus extends StatelessWidget {
  final bool sending;
  final DateTime? sentAt;
  final bool expired;
  final String? error;
  final String sender;
  const _SendStatus({
    required this.sending,
    required this.sentAt,
    required this.expired,
    required this.error,
    required this.sender,
  });

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = error != null
        ? (Icons.error_outline_rounded, FrColors.danger, error!)
        : sending || sentAt == null
            ? (Icons.schedule_send_rounded, FrColors.info, tr('Sending…'))
            : (
                expired
                    ? Icons.mark_email_unread_outlined
                    : Icons.mark_email_read_rounded,
                expired ? FrColors.muted : FrColors.success,
                tr('Sent at {time} from {sender}. Not in your inbox? Check Spam or Promotions.',
                    {'time': fmtClock(sentAt!), 'sender': sender}),
              );
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

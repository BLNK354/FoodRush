import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/browser/browser.dart' as browser;
import '../../shared/password_strength.dart';
import '../../shared/premium.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

/// A Firebase email link (verify email, reset password, undo an email
/// change) opened in the app. Firebase's emails point here once the custom
/// action URL is set in the console (Authentication → Templates).
class AuthActionLink {
  final String mode;
  final String code;
  const AuthActionLink(this.mode, this.code);

  /// The link this page load came from, if any. Captured once at startup
  /// (before routing) because the app uses #-routes while Firebase appends
  /// ?mode=…&oobCode=… to the page URL.
  static AuthActionLink? pending;

  static void capture(Uri uri) {
    final mode = uri.queryParameters['mode'];
    final code = uri.queryParameters['oobCode'];
    if (mode == null || code == null || code.isEmpty) return;
    pending = AuthActionLink(mode, code);
    // Drop the one-time code from the address bar and history.
    browser.replaceUrl('${uri.origin}/#/auth/action');
  }
}

enum _Stage { working, expired, invalid, verified, resetForm, resetDone, recovered, failed }

class AuthActionScreen extends ConsumerStatefulWidget {
  const AuthActionScreen({super.key});

  @override
  ConsumerState<AuthActionScreen> createState() => _AuthActionScreenState();
}

class _AuthActionScreenState extends ConsumerState<AuthActionScreen> {
  final _link = AuthActionLink.pending;
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  _Stage _stage = _Stage.working;
  String? _email;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _set(_Stage s) {
    if (mounted) setState(() => _stage = s);
  }

  Future<void> _run() async {
    final link = _link;
    if (link == null) return _set(_Stage.invalid);
    final auth = FirebaseAuth.instance;
    try {
      switch (link.mode) {
        case 'verifyEmail':
          final info = await auth.checkActionCode(link.code);
          _email = info.data['email'] as String?;
          // Our own expiry: the link counts from the server-stamped send
          // time, whatever Firebase itself would still accept.
          final sent = _email == null
              ? null
              : await AuthController.loadVerifyLink(_email!);
          if (sent == null || sent.isExpired()) return _set(_Stage.expired);
          await auth.applyActionCode(link.code);
          if (auth.currentUser != null) {
            await ref
                .read(authControllerProvider.notifier)
                .refreshEmailVerified();
          }
          return _set(_Stage.verified);
        case 'resetPassword':
          _email = await auth.verifyPasswordResetCode(link.code);
          return _set(_Stage.resetForm);
        case 'recoverEmail':
          final info = await auth.checkActionCode(link.code);
          _email = info.data['email'] as String?;
          await auth.applyActionCode(link.code);
          return _set(_Stage.recovered);
        default:
          return _set(_Stage.invalid);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'expired-action-code') return _set(_Stage.expired);
      if (e.code == 'invalid-action-code') return _set(_Stage.invalid);
      _error = e.message;
      _set(_Stage.failed);
    } catch (e) {
      _error = '$e';
      _set(_Stage.failed);
    }
  }

  Future<void> _saveNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
          code: _link!.code, newPassword: _password.text);
      _set(_Stage.resetDone);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'expired-action-code') {
        _set(_Stage.expired);
      } else if (e.code == 'invalid-action-code') {
        _set(_Stage.invalid);
      } else if (mounted) {
        showSnack(context, e.message ?? 'Could not save the password.',
            error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    AuthActionLink.pending = null;
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, List<Color> colors, String title, String body) =
        switch (_stage) {
      _Stage.working => (
          Icons.hourglass_top_rounded,
          const [Color(0xFFFF7A59), FrColors.primary],
          tr('Checking your link…'),
          '',
        ),
      _Stage.expired => (
          Icons.timer_off_rounded,
          const [Color(0xFFFFC069), Color(0xFFE07A00)],
          tr('This link has expired'),
          tr('Links work for {m} minutes. Open FoodRush and send a new one.',
              {'m': kVerifyLinkLifetime.inMinutes}),
        ),
      _Stage.invalid => (
          Icons.link_off_rounded,
          const [Color(0xFFB0B0B0), Color(0xFF6E6864)],
          tr('This link can’t be used'),
          tr('It was already used, or a newer email replaced it. Open FoodRush to continue.'),
        ),
      _Stage.verified => (
          Icons.verified_rounded,
          const [Color(0xFF5BD68A), Color(0xFF15803D)],
          tr('Email verified!'),
          tr('{email} is confirmed. You can order now.', {'email': _email ?? ''}),
        ),
      _Stage.resetForm => (
          Icons.lock_reset_rounded,
          const [Color(0xFFFF7A59), FrColors.primary],
          tr('Choose a new password'),
          tr('For {email}', {'email': _email ?? ''}),
        ),
      _Stage.resetDone => (
          Icons.lock_open_rounded,
          const [Color(0xFF5BD68A), Color(0xFF15803D)],
          tr('Password changed'),
          tr('Sign in with your new password.'),
        ),
      _Stage.recovered => (
          Icons.restore_rounded,
          const [Color(0xFF6CB2FF), Color(0xFF1976D2)],
          tr('Email change undone'),
          tr('Your sign-in email is {email} again. Consider changing your password too.',
              {'email': _email ?? ''}),
        ),
      _Stage.failed => (
          Icons.error_outline_rounded,
          const [Color(0xFFFF8A8A), Color(0xFFD32F2F)],
          tr('Something went wrong'),
          _error ?? '',
        ),
    };

    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: FadeSlideIn(
                key: ValueKey(_stage),
                child: GlassPanel(
                  borderRadius: BorderRadius.circular(FrRadius.xl + 4),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: ClayOrb(icon: icon, size: 88, colors: colors)),
                      const SizedBox(height: 18),
                      Text(title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      if (body.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: FrColors.muted, height: 1.4)),
                      ],
                      const SizedBox(height: 24),
                      if (_stage == _Stage.working)
                        const Center(child: CircularProgressIndicator())
                      else if (_stage == _Stage.resetForm)
                        _resetForm()
                      else
                        GradientButton(
                          onPressed: _leave,
                          icon: Icons.arrow_forward_rounded,
                          label: _stage == _Stage.expired
                              ? tr('Get a new link')
                              : tr('Continue to FoodRush'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _resetForm() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FrTextField(
              controller: _password,
              label: tr('New password'),
              obscure: true,
              maxLength: Limits.password,
              validator: (v) => v == null || v.length < kMinPasswordLength
                  ? 'At least $kMinPasswordLength characters'
                  : null,
            ),
            PasswordStrengthMeter(controller: _password),
            const SizedBox(height: 14),
            FrTextField(
              controller: _confirm,
              label: tr('Confirm'),
              obscure: true,
              maxLength: Limits.password,
              validator: (v) =>
                  v != _password.text ? 'Passwords do not match' : null,
              onSubmitted: (_) => _saveNewPassword(),
            ),
            const SizedBox(height: 20),
            GradientButton(
              onPressed: _saveNewPassword,
              busy: _busy,
              icon: Icons.check_rounded,
              label: tr('Save new password'),
            ),
          ],
        ),
      );
}

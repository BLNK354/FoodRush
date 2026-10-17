import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/language_picker.dart';
import '../../shared/premium.dart';
import '../../shared/responsive.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final err = await ref
        .read(authControllerProvider.notifier)
        .signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) showSnack(context, err, error: true);
    // Router redirect handles navigation on success.
  }

  Future<void> _forgotPassword() async {
    final address = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(initialEmail: _email.text.trim()),
    );
    if (address == null || !mounted) return;
    final err = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(address);
    if (!mounted) return;
    showSnack(
      context,
      err ?? 'If an account exists for $address, a reset link is on its way.',
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = !FrBreakpoints.isCompact(MediaQuery.sizeOf(context).width);
    final notice = ref.watch(authControllerProvider.select((a) => a.notice));

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Welcome back'),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(tr('Sign in to skip the line at your favorite stalls.'),
              style: TextStyle(color: FrColors.muted)),
          const SizedBox(height: 24),
          if (notice != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FrColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(FrRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: FrColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(notice,
                        style: TextStyle(
                            color: FrColors.danger,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          FrTextField(
            controller: _email,
            label: tr('Email'),
            keyboardType: TextInputType.emailAddress,
            maxLength: Limits.email,
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          FrTextField(
            controller: _password,
            label: tr('Password'),
            obscure: true,
            maxLength: Limits.password,
            validator: (v) =>
                v == null || v.isEmpty ? 'Password is required' : null,
            onSubmitted: (_) {
              if (!_busy) _submit();
            },
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _forgotPassword,
              child: Text(tr('Forgot password?')),
            ),
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: tr('Sign in'),
            icon: Icons.arrow_forward_rounded,
            busy: _busy,
            onPressed: _submit,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(tr("Don't have an account?"),
                  style: TextStyle(color: FrColors.muted)),
              TextButton(
                onPressed: () => context.go('/register'),
                child: Text(tr('Create one')),
              ),
            ],
          ),
          const Center(child: LanguageButton()),
        ],
      ),
    );

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: wide
                  ? Padding(
                      padding: const EdgeInsets.all(32),
                      child: Row(
                        children: [
                          Expanded(child: FadeSlideIn(child: _brandPanel())),
                          const SizedBox(width: 56),
                          SizedBox(
                            width: 440,
                            child: FadeSlideIn(
                              index: 2,
                              child: _formCard(form),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      child: Column(
                        children: [
                          FadeSlideIn(child: _compactBrand()),
                          const SizedBox(height: 8),
                          FadeSlideIn(index: 2, child: _formCard(form)),
                        ],
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formCard(Widget form) => GlassPanel(
        borderRadius: BorderRadius.circular(FrRadius.xl + 4),
        padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
        child: form,
      );

  Widget _compactBrand() => Column(
        children: [
          const FloatingFoodScene(height: 210),
          GradientText(Brand.current.appName,
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.4)),
          const SizedBox(height: 2),
          Text((Brand.current.tagline.isNotEmpty
              ? Brand.current.tagline
              : tr('{u} · order ahead, skip the line', {'u': kUniversityName})),
              style: TextStyle(
                  fontSize: 13.5,
                  color: FrColors.muted,
                  fontWeight: FontWeight.w600)),
        ],
      );

  Widget _brandPanel() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const BrandMark(size: 48),
              const SizedBox(width: 14),
              GradientText(Brand.current.appName,
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2)),
            ],
          ),
          const FloatingFoodScene(height: 300),
          Text(
            tr('Order ahead.\nSkip the line.'),
            style: TextStyle(
              fontSize: 46,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -2,
              color: FrColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            tr('Campus food from your favorite {u} stalls, ready when you '
                'are. No deliveries, no waiting.', {'u': kUniversityName}),
            style: TextStyle(fontSize: 16, height: 1.5, color: FrColors.muted),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, label) in [
                (Icons.bolt_rounded, 'Order ahead'),
                (Icons.timer_outlined, 'Skip the line'),
                (Icons.account_balance_wallet_outlined, 'GCash & cash'),
              ])
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: FrColors.glass,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: FrColors.hairline),
                    boxShadow: FrShadows.soft,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 17, color: FrColors.primary),
                      const SizedBox(width: 6),
                      Text(tr(label),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
}

/// Asks for the email to send a reset link to; pops with it (or null).
class _ResetPasswordDialog extends StatefulWidget {
  final String initialEmail;
  const _ResetPasswordDialog({required this.initialEmail});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Reset your password')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr("We'll email you a link to set a new password."),
              style: TextStyle(color: FrColors.muted)),
          const SizedBox(height: 16),
          FrTextField(
            controller: _email,
            label: tr('Email'),
            keyboardType: TextInputType.emailAddress,
            maxLength: Limits.email,
            validator: validateEmail,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          onPressed: () {
            final err = validateEmail(_email.text);
            if (err != null) {
              showSnack(context, err, error: true);
              return;
            }
            Navigator.pop(context, _email.text.trim());
          },
          child: Text(tr('Send link')),
        ),
      ],
    );
  }
}

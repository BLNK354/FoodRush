import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/responsive.dart';
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

  @override
  Widget build(BuildContext context) {
    final wide = !FrBreakpoints.isCompact(MediaQuery.sizeOf(context).width);

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome back',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Sign in to skip the line at your favorite stalls.',
              style: TextStyle(color: FrColors.muted)),
          const SizedBox(height: 24),
          FrTextField(
            controller: _email,
            label: 'Email',
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Email is required' : null,
          ),
          const SizedBox(height: 16),
          FrTextField(
            controller: _password,
            label: 'Password',
            obscure: true,
            validator: (v) =>
                v == null || v.isEmpty ? 'Password is required' : null,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Sign in'),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Don't have an account?",
                  style: TextStyle(color: FrColors.muted)),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text('Create one'),
              ),
            ],
          ),
        ],
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: _brandPanel()),
                        const SizedBox(width: 48),
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: form,
                            ),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(child: form),
            ),
          ),
        ),
      ),
    );
  }

  Widget _brandPanel() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FrColors.primary,
              borderRadius: BorderRadius.circular(FrRadius.lg),
            ),
            child: const Icon(Icons.lunch_dining, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 20),
          const Text('FoodRush',
              style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const Text('for $kUniversityName',
              style: TextStyle(fontSize: 18, color: FrColors.muted)),
          const SizedBox(height: 16),
          const Text(
            'Order ahead. Skip the line.\nPick up at the stall — no deliveries, no waiting.',
            style: TextStyle(fontSize: 15, height: 1.5),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final f in ['Order ahead', 'Skip the line', 'GCash & cash'])
                Chip(
                  avatar: Icon(Icons.check_circle,
                      size: 16, color: FrColors.success),
                  label: Text(f),
                ),
            ],
          ),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/widgets.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _studentNumber = TextEditingController();
  final _stallName = TextEditingController();
  final _stallDescription = TextEditingController();

  String _role = kRoleCustomer;
  bool _busy = false;
  bool _agreed = false;

  @override
  void dispose() {
    for (final c in [
      _email, _password, _confirm, _fullName, _phone, _studentNumber,
      _stallName, _stallDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showSnack(context, 'Please agree to the ground rules to continue.',
          error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await ref.read(authControllerProvider.notifier).register(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          phone: _phone.text,
          studentNumber:
              _role == kRoleCustomer ? _studentNumber.text : null,
          role: _role,
          stallName: _stallName.text,
          stallDescription: _stallDescription.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err == '__CONFIRM_EMAIL__') {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Check your email'),
          content: const Text(
              'We sent a confirmation link to your inbox. Click it, then sign in.'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) context.go('/login');
      return;
    }
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    // Signed in immediately (email confirmation disabled): router redirects.
  }

  @override
  Widget build(BuildContext context) {
    final form = Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Create your account',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // Role picker
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                    value: kRoleCustomer,
                    icon: Icon(Icons.person_outline),
                    label: Text('Student')),
                ButtonSegment(
                    value: kRoleVendor,
                    icon: Icon(Icons.storefront_outlined),
                    label: Text('Stall owner')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 16),

            FrTextField(
              controller: _fullName,
              label: 'Full name',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            FrTextField(
              controller: _email,
              label: _role == kRoleCustomer
                  ? 'LPU email (@$kUniversityDomain)'
                  : 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (_role == kRoleCustomer && !isLpuEmail(v)) {
                  return 'Must be an @$kUniversityDomain email';
                }
                return null;
              },
            ),

            if (_role == kRoleCustomer) ...[
              const SizedBox(height: 16),
              FrTextField(
                controller: _studentNumber,
                label: 'Student number (optional)',
                keyboardType: TextInputType.text,
              ),
            ],

            const SizedBox(height: 16),
            FrTextField(
              controller: _phone,
              label: 'Mobile number (optional)',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FrTextField(
                    controller: _password,
                    label: 'Password',
                    obscure: true,
                    validator: (v) =>
                        v == null || v.length < kMinPasswordLength
                            ? 'At least $kMinPasswordLength characters'
                            : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FrTextField(
                    controller: _confirm,
                    label: 'Confirm',
                    obscure: true,
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                ),
              ],
            ),

            if (_role == kRoleVendor) ...[
              const SizedBox(height: 20),
              const SectionHeader('Stall details'),
              FrTextField(
                controller: _stallName,
                label: 'Stall name',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Stall name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              FrTextField(
                controller: _stallDescription,
                label: 'Short description',
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FrColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(FrRadius.md),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: FrColors.warning, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your stall will be reviewed by the FoodRush team before it goes live.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            CheckboxListTile(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I understand: pickup only (no deliveries), pay by GCash or cash, and I am a bona fide member of the LPU community.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account?',
                    style: TextStyle(color: FrColors.muted)),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: form,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

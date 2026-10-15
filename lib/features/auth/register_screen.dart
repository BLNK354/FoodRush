import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../shared/validation.dart';
import '../../shared/password_strength.dart';
import '../../shared/premium.dart';
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
  bool _bootstrapOpen = false;

  @override
  void initState() {
    super.initState();
    _checkBootstrap();
  }

  /// The Admin tab exists only while no admin account exists — it disappears
  /// the moment the first signup completes.
  Future<void> _checkBootstrap() async {
    final marker = await FirebaseFirestore.instance
        .collection(kColSettings)
        .doc('app_bootstrapped')
        .get();
    if (!mounted) return;
    setState(() {
      _bootstrapOpen = !marker.exists;
      if (!_bootstrapOpen && _role == kRoleAdmin) _role = kRoleCustomer;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _email,
      _password,
      _confirm,
      _fullName,
      _phone,
      _studentNumber,
      _stallName,
      _stallDescription,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      showSnack(
        context,
        tr('Please agree to the ground rules to continue.'),
        error: true,
      );
      return;
    }
    if (_role == kRoleAdmin && !_bootstrapOpen) {
      showSnack(
        context,
        'An admin already exists — register as a student or stall owner.',
        error: true,
      );
      return;
    }
    setState(() => _busy = true);
    final err = await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _email.text,
          password: _password.text,
          fullName: _fullName.text,
          phone: _phone.text,
          studentNumber: _role == kRoleCustomer ? _studentNumber.text : null,
          role: _role,
          stallName: _stallName.text,
          stallDescription: _stallDescription.text,
        );
    if (!mounted) return;
    setState(() => _busy = false);

    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    // Signed in: the router shows "Verify your email" until the link is clicked.
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
            Text(
              tr('Create your account'),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),

            // Role picker — the Admin segment only exists while the
            // first-account-admin window is open.
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: kRoleCustomer,
                  icon: Icon(Icons.person_outline),
                  label: Text(tr('Student')),
                ),
                if (_bootstrapOpen)
                  const ButtonSegment(
                    value: kRoleAdmin,
                    icon: Icon(Icons.admin_panel_settings_outlined),
                    label: Text('Admin'),
                  ),
                ButtonSegment(
                  value: kRoleVendor,
                  icon: Icon(Icons.storefront_outlined),
                  label: Text(tr('Stall owner')),
                ),
                ButtonSegment(
                  value: kRoleStaff,
                  icon: Icon(Icons.badge_outlined),
                  label: Text(tr('Staff')),
                ),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),

            if (_role == kRoleStaff) ...[
              const SizedBox(height: 12),
              Text(
                'For people who work at a stall. After signing up, ask the stall '
                'owner to add your email under Settings → Staff.',
                style: TextStyle(color: FrColors.muted, fontSize: 13),
              ),
            ],

            // Admin explainer: shown only when the Admin tab is selected.
            if (_role == kRoleAdmin) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FrColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(FrRadius.md),
                  border: Border.all(color: FrColors.warning, width: 1.2),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings,
                      color: FrColors.warning,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You are creating the PLATFORM ADMIN — the account '
                        'that verifies stalls, manages users, and oversees '
                        'every order. This tab disappears once an admin '
                        'exists, so this should only be for the person '
                        'setting up FoodRush.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            FrTextField(
              controller: _fullName,
              label: tr('Full name'),
              maxLength: Limits.name,
              validator: validatePersonName,
            ),
            const SizedBox(height: 16),

            FrTextField(
              controller: _email,
              label: _role == kRoleCustomer
                  ? 'LPU email (@$kUniversityDomain)'
                  : 'Email',
              keyboardType: TextInputType.emailAddress,
              maxLength: Limits.email,
              validator: (v) {
                final err = validateEmail(v);
                if (err != null) return err;
                if (_role == kRoleCustomer && !isLpuEmail(v!)) {
                  return 'Must be an @$kUniversityDomain email';
                }
                return null;
              },
            ),

            if (_role == kRoleCustomer) ...[
              const SizedBox(height: 16),
              FrTextField(
                controller: _studentNumber,
                label: tr('Student number'),
                hint: '2024-12345',
                keyboardType: TextInputType.text,
                maxLength: Limits.studentNumber,
                validator: validateStudentNumber,
              ),
            ],

            const SizedBox(height: 16),
            FrTextField(
              controller: _phone,
              label: tr('Mobile number (optional)'),
              keyboardType: TextInputType.phone,
              maxLength: Limits.phone,
              validator: validatePhone,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FrTextField(
                    controller: _password,
                    label: tr('Password'),
                    obscure: true,
                    maxLength: Limits.password,
                    validator: (v) => v == null || v.length < kMinPasswordLength
                        ? 'At least $kMinPasswordLength characters'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FrTextField(
                    controller: _confirm,
                    label: tr('Confirm'),
                    obscure: true,
                    maxLength: Limits.password,
                    validator: (v) =>
                        v != _password.text ? 'Passwords do not match' : null,
                  ),
                ),
              ],
            ),
            PasswordStrengthMeter(controller: _password),

            if (_role == kRoleVendor) ...[
              const SizedBox(height: 20),
              const SectionHeader('Stall details'),
              FrTextField(
                controller: _stallName,
                label: 'Stall name',
                maxLength: Limits.name,
                validator: (v) => validateText(
                  v,
                  max: Limits.name,
                  required: true,
                  min: 2,
                  label: 'Stall name',
                ),
              ),
              const SizedBox(height: 12),
              FrTextField(
                controller: _stallDescription,
                label: 'Short description',
                maxLines: 2,
                maxLength: Limits.description,
                validator: (v) => validateText(v, max: Limits.description),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FrColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(FrRadius.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: FrColors.warning, size: 20),
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
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.push('/privacy'),
                child: Text(tr('How we use your data (privacy notice)')),
              ),
            ),
            const SizedBox(height: 8),
            GradientButton(
              onPressed: _submit,
              busy: _busy,
              icon: Icons.arrow_forward_rounded,
              label: tr('Create account'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr('Already have an account?'),
                  style: TextStyle(color: FrColors.muted),
                ),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(tr('Sign in')),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  children: [
                    FadeSlideIn(child: _compactBrand()),
                    const SizedBox(height: 22),
                    FadeSlideIn(
                      index: 2,
                      child: GlassPanel(
                        borderRadius: BorderRadius.circular(FrRadius.xl + 4),
                        padding: const EdgeInsets.all(28),
                        child: form,
                      ),
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

  Widget _compactBrand() => Column(
    children: [
      const BrandMark(size: 60),
      const SizedBox(height: 14),
      GradientText(
        'FoodRush',
        style: const TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w900,
          letterSpacing: -1.2,
        ),
      ),
      Text(
        tr('{u} · order ahead, skip the line', {'u': kUniversityName}),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13.5,
          color: FrColors.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../providers/theme_mode.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

/// The signed-in user's own account: edit name/phone (and student number for
/// customers), request a password-reset email. Shared by every role.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _studentNumber = TextEditingController();
  bool _saving = false;
  bool _sendingReset = false;

  @override
  void initState() {
    super.initState();
    final p = ref.read(authControllerProvider).profile;
    _fullName.text = p?.fullName ?? '';
    _phone.text = p?.phone ?? '';
    _studentNumber.text = p?.studentNumber ?? '';
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _studentNumber.dispose();
    super.dispose();
  }

  String _home(String? role) => switch (role) {
    kRoleAdmin => '/admin',
    kRoleVendor => '/vendor',
    _ => '/shop',
  };

  Future<void> _save(bool isCustomer) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateMyProfile(
            fullName: _fullName.text,
            phone: _phone.text,
            studentNumber: isCustomer ? _studentNumber.text : null,
          );
      if (mounted) showSnack(context, 'Profile saved.');
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReset(String email) async {
    setState(() => _sendingReset = true);
    final err = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;
    setState(() => _sendingReset = false);
    showSnack(
      context,
      err ?? 'Password reset link sent to $email.',
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final isCustomer = profile.role == kRoleCustomer;
    final roleLabel = switch (profile.role) {
      kRoleAdmin => 'Admin',
      kRoleVendor => 'Stall owner',
      _ => 'Student',
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_home(profile.role)),
        ),
        title: const Text('My profile'),
      ),
      body: FrPage(
        title: profile.fullName.isEmpty ? 'My profile' : profile.fullName,
        subtitle: '${profile.email} · $roleLabel',
        children: [
          // Align loosens the page's stretch constraint so maxWidth applies.
          Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SectionHeader('Account details'),
                            FrTextField(
                              controller: _fullName,
                              label: 'Full name',
                              maxLength: Limits.name,
                              validator: validatePersonName,
                            ),
                            const SizedBox(height: 14),
                            FrTextField(
                              controller: _phone,
                              label: 'Mobile number (optional)',
                              keyboardType: TextInputType.phone,
                              maxLength: Limits.phone,
                              validator: validatePhone,
                              hint: '09XXXXXXXXX',
                            ),
                            if (isCustomer) ...[
                              const SizedBox(height: 14),
                              FrTextField(
                                controller: _studentNumber,
                                label: 'Student number (optional)',
                                maxLength: Limits.studentNumber,
                                validator: validateStudentNumber,
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save(isCustomer),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              child: _saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save changes'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader('Password'),
                          Text(
                            'We\'ll email a secure link to ${profile.email} '
                            'where you can choose a new password.',
                            style: TextStyle(
                              color: FrColors.muted,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            onPressed: _sendingReset
                                ? null
                                : () => _sendReset(profile.email),
                            icon: const Icon(Icons.lock_reset),
                            label: const Text('Send password reset link'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionHeader('Appearance'),
                          SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto),
                                  label: Text('System')),
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text('Light')),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text('Dark')),
                            ],
                            selected: {ref.watch(themeModeProvider)},
                            onSelectionChanged: (s) => ref
                                .read(themeModeProvider.notifier)
                                .set(s.first),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    icon: Icon(Icons.logout, color: FrColors.danger),
                    label: Text(
                      'Sign out',
                      style: TextStyle(color: FrColors.danger),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

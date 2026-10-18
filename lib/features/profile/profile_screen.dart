import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_controller.dart';
import '../../providers/repository.dart';
import '../../providers/theme_mode.dart';
import '../../shared/language_picker.dart';
import '../../shared/user_avatar.dart';
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
      if (mounted) showSnack(context, tr('Profile saved.'));
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;
    final err =
        await ref.read(authControllerProvider.notifier).deleteMyAccount(password);
    if (!mounted) return;
    if (err != null) {
      showSnack(this.context, err, error: true);
    }
    // On success the auth listener signs out and the router shows login.
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
      kRoleVendor => tr('Stall owner'),
      _ => tr('Student'),
    };

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: tr('Back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(_home(profile.role)),
        ),
        title: Text(tr('My profile')),
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
                  _PhotoCard(uid: profile.id, name: profile.fullName),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SectionHeader(tr('Account details')),
                            FrTextField(
                              controller: _fullName,
                              label: tr('Full name'),
                              maxLength: Limits.name,
                              validator: validatePersonName,
                            ),
                            const SizedBox(height: 14),
                            FrTextField(
                              controller: _phone,
                              label: tr('Mobile number (optional)'),
                              keyboardType: TextInputType.phone,
                              maxLength: Limits.phone,
                              validator: validatePhone,
                              hint: '09XXXXXXXXX',
                            ),
                            if (isCustomer) ...[
                              const SizedBox(height: 14),
                              FrTextField(
                                controller: _studentNumber,
                                label: tr('Student number'),
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
                                  : Text(tr('Save changes')),
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
                          SectionHeader(tr('Password')),
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
                            label: Text(tr('Send password reset link')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(tr('Appearance')),
                          SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                  value: ThemeMode.system,
                                  icon: Icon(Icons.brightness_auto),
                                  label: Text(tr('System'))),
                              ButtonSegment(
                                  value: ThemeMode.light,
                                  icon: Icon(Icons.light_mode_outlined),
                                  label: Text(tr('Light'))),
                              ButtonSegment(
                                  value: ThemeMode.dark,
                                  icon: Icon(Icons.dark_mode_outlined),
                                  label: Text(tr('Dark'))),
                            ],
                            selected: {ref.watch(themeModeProvider)},
                            onSelectionChanged: (s) => ref
                                .read(themeModeProvider.notifier)
                                .set(s.first),
                          ),
                          const SizedBox(height: 16),
                          SectionHeader(tr('Language')),
                          OutlinedButton.icon(
                            onPressed: () => showLanguagePicker(context, ref),
                            icon: const Icon(Icons.language_rounded),
                            label: Row(
                              children: [
                                Expanded(
                                  child: Text(languageFor(
                                          ref.watch(languageProvider))
                                      .nativeName),
                                ),
                                const Icon(Icons.expand_more_rounded),
                              ],
                            ),
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
                      tr('Sign out'),
                      style: TextStyle(color: FrColors.danger),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isCustomer)
                    TextButton.icon(
                      onPressed: () => _deleteAccount(context),
                      icon: Icon(Icons.delete_forever, color: FrColors.danger),
                      label: Text(tr('Delete my account'),
                          style: TextStyle(color: FrColors.danger)),
                    )
                  else
                    Text(
                      'To close a staff or admin account, ask a FoodRush admin.',
                      style: TextStyle(color: FrColors.muted, fontSize: 12.5),
                    ),
                  TextButton(
                    onPressed: () => context.push('/privacy'),
                    child: Text(tr('Privacy notice')),
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

/// Confirms account deletion: explains what happens, asks for the password
/// (Firebase needs a fresh sign-in) and an explicit tick. Pops with it.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _understood = false;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This permanently deletes your profile, favourites and login. '
              'Your name is removed from past orders and reviews; stalls keep '
              'the anonymous sales record. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _password,
              obscureText: true,
              maxLength: 128,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  labelText: 'Your password', counterText: ''),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _understood,
              onChanged: (v) => setState(() => _understood = v ?? false),
              title: const Text('I understand this is permanent',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: FrColors.danger),
          onPressed: !_understood || _password.text.isEmpty
              ? null
              : () => Navigator.pop(context, _password.text),
          child: const Text('Delete forever'),
        ),
      ],
    );
  }
}

/// The person's own photo: upload (centre-cropped square), change, remove.
/// Stalls see it on orders so they hand food to the right person.
class _PhotoCard extends StatefulWidget {
  final String uid;
  final String name;
  const _PhotoCard({required this.uid, required this.name});

  @override
  State<_PhotoCard> createState() => _PhotoCardState();
}

class _PhotoCardState extends State<_PhotoCard> {
  bool _busy = false;
  late final Stream<String?> _photo =
      Repository.instance.streamAvatar(widget.uid);

  Future<void> _pick() async {
    final picked = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    final Uint8List? bytes = picked?.files.single.bytes;
    if (bytes == null) return;
    setState(() => _busy = true);
    try {
      final url = await Repository.instance.makeAvatar(bytes);
      await Repository.instance.setMyAvatar(url);
      if (mounted) showSnack(context, tr('Photo updated.'));
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await Repository.instance.setMyAvatar(null);
      if (mounted) showSnack(context, tr('Photo removed.'));
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<String?>(
          stream: _photo,
          builder: (context, snap) {
            final hasPhoto = snap.data != null;
            return Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(uid: widget.uid, name: widget.name, size: 92),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Material(
                        color: FrColors.primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _busy ? null : _pick,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: _busy
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: FrColors.onPrimary))
                                : Icon(Icons.photo_camera_rounded,
                                    size: 16, color: FrColors.onPrimary),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Profile photo'),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        tr('Stalls see this photo when you order, so they can hand your food to the right person.'),
                        style: TextStyle(
                            color: FrColors.muted, fontSize: 12.5, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pick,
                            icon: const Icon(Icons.upload_rounded, size: 18),
                            label: Text(hasPhoto
                                ? tr('Change photo')
                                : tr('Add photo')),
                          ),
                          if (hasPhoto)
                            TextButton.icon(
                              onPressed: _busy ? null : _remove,
                              icon: const Icon(Icons.delete_outline_rounded,
                                  size: 18),
                              label: Text(tr('Remove photo')),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

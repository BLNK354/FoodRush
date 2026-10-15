import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

String _roleLabel(String role) => switch (role) {
  kRoleAdmin => 'Admin',
  kRoleVendor => 'Stall owner',
  _ => 'Student',
};

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<Profile> _profiles = [];
  bool _loading = true;
  String _roleFilter = 'all';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profiles = await Repository.instance.listProfiles();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load users: $e', error: true);
    }
  }

  List<Profile> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _profiles.where((p) {
      if (_roleFilter != 'all' && p.role != _roleFilter) return false;
      if (q.isEmpty) return true;
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          (p.studentNumber?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Users',
      subtitle: 'Everyone with a FoodRush account. Tap a user to edit.',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      children: [
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          inputFormatters: [LengthLimitingTextInputFormatter(Limits.search)],
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search name, email or student number',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in const [
              ('all', 'All'),
              (kRoleCustomer, 'Students'),
              (kRoleVendor, 'Stall owners'),
              (kRoleAdmin, 'Admins'),
            ])
              ChoiceChip(
                label: Text(f.$2),
                selected: _roleFilter == f.$1,
                onSelected: (_) => setState(() => _roleFilter = f.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _profiles.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_filtered.isEmpty)
          const EmptyState(icon: Icons.people_outline, title: 'No users found')
        else
          ..._filtered.map(_userTile),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _userTile(Profile p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _edit(p),
        leading: CircleAvatar(
          backgroundColor: FrColors.primary.withValues(alpha: 0.12),
          child: Text(
            p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: FrColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          p.fullName.isEmpty ? '(no name)' : p.fullName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        // Chips live in the subtitle: ListTile.trailing is width-constrained,
        // and the SwitchListTile that used to sit there failed layout.
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(p.email, overflow: TextOverflow.ellipsis),
              StatusChip(
                _roleLabel(p.role),
                color: p.role == kRoleAdmin ? FrColors.primary : FrColors.info,
              ),
              p.isActive
                  ? StatusChip('Active', color: FrColors.success)
                  : StatusChip('Deactivated', color: FrColors.danger),
            ],
          ),
        ),
        trailing: Icon(Icons.edit_outlined, color: FrColors.muted),
      ),
    );
  }

  Future<void> _edit(Profile p) async {
    final me = ref.read(authControllerProvider).profile?.id;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditUserDialog(profile: p, isSelf: p.id == me),
    );
    if (saved == true) await _load();
  }
}

class _EditUserDialog extends StatefulWidget {
  final Profile profile;
  final bool isSelf;
  const _EditUserDialog({required this.profile, required this.isSelf});

  @override
  State<_EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<_EditUserDialog> {
  late final _fullName = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _studentNumber = TextEditingController(
    text: widget.profile.studentNumber ?? '',
  );
  final _stallName = TextEditingController();
  late String _role = widget.profile.role;
  late bool _active = widget.profile.isActive;
  bool _saving = false;

  /// Becoming a stall owner needs a stall; asked for only if they have none.
  bool? _hasStall;

  @override
  void initState() {
    super.initState();
    Repository.instance.userOwnsStall(widget.profile.id).then((v) {
      if (mounted) setState(() => _hasStall = v);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _studentNumber.dispose();
    _stallName.dispose();
    super.dispose();
  }

  bool get _needsStall => _role == kRoleVendor && _hasStall == false;

  Future<void> _save() async {
    final err = firstError([
      validatePersonName(_fullName.text),
      validatePhone(_phone.text),
      validateStudentNumber(_studentNumber.text),
      if (_needsStall)
        validateText(_stallName.text,
            max: Limits.name, required: true, min: 2, label: 'Stall name'),
    ]);
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    if (_needsStall && _stallName.text.trim().isEmpty) {
      showSnack(
        context,
        'Enter a stall name for the new stall owner.',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await Repository.instance.adminUpdateUser(
        widget.profile.id,
        fullName: _fullName.text,
        phone: _phone.text,
        studentNumber: _studentNumber.text,
        role: _role,
        isActive: _active,
        stallName: _needsStall ? _stallName.text : null,
      );
      if (!mounted) return;
      showSnack(context, 'User updated.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showSnack(context, 'Update failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit user'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.profile.email,
                style: TextStyle(color: FrColors.muted),
              ),
              const SizedBox(height: 16),
              FrTextField(
                controller: _fullName,
                label: 'Full name',
                maxLength: Limits.name,
                validator: validatePersonName,
              ),
              const SizedBox(height: 12),
              FrTextField(
                controller: _phone,
                label: 'Mobile number',
                keyboardType: TextInputType.phone,
                maxLength: Limits.phone,
                validator: validatePhone,
              ),
              const SizedBox(height: 12),
              FrTextField(
                controller: _studentNumber,
                label: 'Student number',
                maxLength: Limits.studentNumber,
                validator: validateStudentNumber,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: [
                  for (final r in const [
                    kRoleCustomer,
                    kRoleVendor,
                    kRoleAdmin,
                  ])
                    DropdownMenuItem(value: r, child: Text(_roleLabel(r))),
                ],
                // Admins can't change their own role (would lock them out).
                onChanged: widget.isSelf || _saving
                    ? null
                    : (v) => setState(() => _role = v ?? _role),
              ),
              if (_needsStall) ...[
                const SizedBox(height: 12),
                FrTextField(
                  controller: _stallName,
                  label: 'Stall name',
                  maxLength: Limits.name,
                  hint: 'Creates an unverified stall',
                ),
                const SizedBox(height: 4),
                Text(
                  'Verify the new stall under Stalls afterwards.',
                  style: TextStyle(color: FrColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Account active'),
                subtitle: Text(
                  widget.isSelf
                      ? 'You cannot deactivate your own account.'
                      : _active
                      ? 'Can sign in and use FoodRush.'
                      : 'Signed out and blocked from FoodRush.',
                ),
                value: _active,
                onChanged: widget.isSelf || _saving
                    ? null
                    : (v) => setState(() => _active = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

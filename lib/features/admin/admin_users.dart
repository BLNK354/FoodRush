import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  List<Profile> _profiles = [];
  bool _loading = true;
  String _roleFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
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

  List<Profile> get _filtered =>
      _roleFilter == 'all' ? _profiles : _profiles.where((p) => p.role == _roleFilter).toList();

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Users',
      subtitle: 'Everyone with a FoodRush account.',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      children: [
        Wrap(
          spacing: 8,
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
        leading: CircleAvatar(
          backgroundColor: FrColors.primary.withValues(alpha: 0.12),
          child: Text(
            p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
                color: FrColors.primary, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          p.fullName.isEmpty ? '(no name)' : p.fullName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${p.email} · ${p.role}'),
        trailing: p.role == kRoleAdmin
            ? const Chip(label: Text('Admin'))
            : SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.isActive ? 'Active' : 'Deactivated',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: p.isActive ? FrColors.success : FrColors.danger,
                  ),
                ),
                value: p.isActive,
                onChanged: (v) => _setActive(p, v),
              ),
      ),
    );
  }

  Future<void> _setActive(Profile p, bool active) async {
    try {
      await Repository.instance.setUserActive(p.id, active);
      if (!mounted) return;
      showSnack(context, '${p.fullName.isEmpty ? p.email : p.fullName} '
          '${active ? 'reactivated' : 'deactivated'}.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }
}

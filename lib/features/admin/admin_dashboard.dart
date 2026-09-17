import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  Map<String, dynamic>? _stats;
  String? _platformGcash;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await Repository.instance.adminStats();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Could not load stats: $e', error: true);
    }
    try {
      final data = await Repository.instance.getPlatformGcash();
      if (!mounted) return;
      setState(() => _platformGcash = data?['number'] as String?);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Overview',
      subtitle: 'Platform health at a glance.',
      actions: [
        TextButton.icon(
          onPressed: _editPlatformGcash,
          icon: const Icon(Icons.account_balance_wallet, size: 18),
          label: const Text('Platform GCash'),
        ),
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      children: [
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 720;
          return Column(
            children: [
              Row(children: [
                Expanded(
                    child: StatCard(
                        label: 'Customers',
                        value: '${_stats?['customers'] ?? '–'}',
                        icon: Icons.people,
                        color: FrColors.info)),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        label: 'Stalls',
                        value: '${_stats?['vendors'] ?? '–'}',
                        icon: Icons.storefront,
                        color: FrColors.primary)),
                if (wide) ...[
                  const SizedBox(width: 12),
                  Expanded(
                      child: StatCard(
                          label: 'Orders today',
                          value: '${_stats?['ordersToday'] ?? '–'}',
                          icon: Icons.receipt_long,
                          color: FrColors.secondary)),
                ],
              ]),
              if (!wide) ...[
                const SizedBox(height: 12),
                StatCard(
                    label: 'Orders today',
                    value: '${_stats?['ordersToday'] ?? '–'}',
                    icon: Icons.receipt_long,
                    color: FrColors.secondary),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: StatCard(
                        label: 'Pending stall approvals',
                        value: '${_stats?['pendingVendors'] ?? '–'}',
                        icon: Icons.hourglass_top,
                        color: FrColors.warning)),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        label: 'GMV today',
                        value: peso(_stats?['gmvToday'] ?? 0),
                        icon: Icons.payments,
                        color: FrColors.success)),
              ]),
            ],
          );
        }),
        if ((_stats?['pendingVendors'] ?? 0) > 0) ...[
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.pending_actions,
                  color: FrColors.warning),
              title: const Text('Stalls waiting for approval',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'New stall owners can\'t appear in the shop until you verify them.'),
              trailing: FilledButton(
                onPressed: () => context.go('/admin/vendors'),
                child: const Text('Review'),
              ),
            ),
          ),
        ],
        if (_platformGcash == null || _platformGcash!.isEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.wallet_giftcard,
                  color: FrColors.info),
              title: const Text('Platform GCash not set',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text(
                  'Stalls without their own GCash fall back to the platform number.'),
              trailing: OutlinedButton(
                onPressed: _editPlatformGcash,
                child: const Text('Set now'),
              ),
            ),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Future<void> _editPlatformGcash() async {
    final number = TextEditingController(text: _platformGcash ?? '');
    final name = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Platform GCash'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: number,
              decoration: const InputDecoration(
                  labelText: 'GCash number (09XXXXXXXXX)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: const InputDecoration(
                  labelText: 'Account name (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      await Repository.instance.setPlatformGcash(
        number: number.text.trim(),
        name: name.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, 'Platform GCash saved.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Save failed: $e', error: true);
    }
  }
}

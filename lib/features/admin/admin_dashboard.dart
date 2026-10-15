import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/repository.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

/// Banner shown to everyone signed in (students, stalls, admins).
class _AnnouncementEditor extends StatefulWidget {
  const _AnnouncementEditor();

  @override
  State<_AnnouncementEditor> createState() => _AnnouncementEditorState();
}

class _AnnouncementEditorState extends State<_AnnouncementEditor> {
  final _message = TextEditingController();
  bool _active = false;
  String _level = 'info';
  bool _loaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Repository.instance.streamAnnouncement().first.then((a) {
      if (!mounted) return;
      setState(() {
        _message.text = a.message;
        _active = a.active;
        _level = a.level;
        _loaded = true;
      });
    }, onError: (Object _) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _save({bool? active}) async {
    final nextActive = active ?? _active;
    final err = validateText(_message.text,
        max: Limits.announcement, required: nextActive, label: 'Message');
    if (err != null) {
      showSnack(context, err, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await Repository.instance.setAnnouncement(
          message: _message.text, active: nextActive, level: _level);
      if (!mounted) return;
      setState(() => _active = nextActive);
      showSnack(context,
          nextActive ? 'Announcement is live for everyone.' : 'Announcement hidden.');
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionHeader('Announcement')),
                StatusChip(_active ? 'Live' : 'Hidden',
                    color: _active ? FrColors.success : FrColors.muted),
              ],
            ),
            Text('Shown as a banner to everyone who is signed in.',
                style: TextStyle(color: FrColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            FrTextField(
              controller: _message,
              label: 'Message',
              hint: 'e.g. Canteen closed this Friday for the holiday',
              maxLines: 2,
              maxLength: Limits.announcement,
              enabled: _loaded,
              validator: (v) => validateText(v, max: Limits.announcement),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'info',
                        icon: Icon(Icons.campaign_outlined),
                        label: Text('Info')),
                    ButtonSegment(
                        value: 'warning',
                        icon: Icon(Icons.warning_amber_rounded),
                        label: Text('Warning')),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                FilledButton(
                  onPressed: !_loaded || _saving ? null : () => _save(active: true),
                  child: Text(_active ? 'Update' : 'Publish'),
                ),
                if (_active)
                  OutlinedButton(
                    onPressed: _saving ? null : () => _save(active: false),
                    child: const Text('Hide'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
              leading: Icon(Icons.pending_actions,
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
              leading: Icon(Icons.wallet_giftcard,
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
        const SizedBox(height: 20),
        const _AnnouncementEditor(),
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
              keyboardType: TextInputType.phone,
              maxLength: Limits.phone,
              decoration: const InputDecoration(
                  labelText: 'GCash number (09XXXXXXXXX)', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              maxLength: Limits.name,
              decoration: const InputDecoration(
                  labelText: 'Account name (optional)', counterText: ''),
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
    final err = firstError([
      validatePhone(number.text, required: true, label: 'GCash number'),
      name.text.trim().isEmpty ? null : validatePersonName(name.text),
    ]);
    if (err != null) {
      if (mounted) showSnack(context, err, error: true);
      return;
    }
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

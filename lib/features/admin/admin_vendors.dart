import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class AdminVendorsScreen extends ConsumerStatefulWidget {
  const AdminVendorsScreen({super.key});

  @override
  ConsumerState<AdminVendorsScreen> createState() => _AdminVendorsScreenState();
}

class _AdminVendorsScreenState extends ConsumerState<AdminVendorsScreen> {
  List<VendorWithOwner> _vendors = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vendors = await Repository.instance.listAllVendors();
      if (!mounted) return;
      setState(() {
        _vendors = vendors;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load stalls: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _vendors.where((v) => !v.isVerified).toList();
    final approved = _vendors.where((v) => v.isVerified).toList();

    return FrPage(
      title: 'Stalls',
      subtitle: 'Verify stalls before they go live.',
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      children: [
        if (_loading && _vendors.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          if (pending.isNotEmpty) ...[
            SectionHeader('Pending approval (${pending.length})'),
            ...pending.map(_pendingTile),
            const SizedBox(height: 20),
          ],
          SectionHeader('Approved (${approved.length})'),
          if (approved.isEmpty)
            const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No approved stalls yet',
            )
          else
            ...approved.map(_approvedTile),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _pendingTile(VendorWithOwner v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.pending_actions, color: FrColors.warning),
        title: Text(v.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Owner: ${v.ownerName.isEmpty ? v.ownerEmail : v.ownerName} · ${v.ownerEmail}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              onPressed: () => _setVerified(v, true),
              child: const Text('Verify'),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Delete stall',
              icon: const Icon(Icons.delete_outline, color: FrColors.danger),
              onPressed: () => _delete(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _approvedTile(VendorWithOwner v) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.storefront, color: FrColors.success),
        title: Text(v.name,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text('Owner: ${v.ownerEmail}${v.pickupPoint != null ? ' · ${v.pickupPoint}' : ''}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => _setVerified(v, false),
              child: const Text('Revoke',
                  style: TextStyle(color: FrColors.danger)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setVerified(VendorWithOwner v, bool verified) async {
    try {
      await Repository.instance.setVendorVerified(v.id, verified);
      if (!mounted) return;
      showSnack(context,
          '${v.name} ${verified ? 'verified and live' : 'unlisted'}.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Update failed: $e', error: true);
    }
  }

  Future<void> _delete(VendorWithOwner v) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${v.name}?',
      message: 'This removes the stall, its products and menu. The owner account stays.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.deleteVendor(v.id);
      if (!mounted) return;
      showSnack(context, 'Stall deleted.');
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }
}

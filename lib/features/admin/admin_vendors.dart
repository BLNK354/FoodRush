import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

/// Lets an admin remove abusive or fake reviews; deleting also takes the
/// stars back out of the stall's average.
class _ReviewsDialog extends StatefulWidget {
  final Vendor stall;
  const _ReviewsDialog({required this.stall});

  @override
  State<_ReviewsDialog> createState() => _ReviewsDialogState();
}

class _ReviewsDialogState extends State<_ReviewsDialog> {
  List<Review>? _reviews;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Repository.instance
          .listVendorReviews(widget.stall.id, limit: 100);
      if (mounted) setState(() => _reviews = r);
    } catch (e) {
      if (mounted) {
        setState(() => _reviews = []);
        showSnack(context, 'Could not load reviews: $e', error: true);
      }
    }
  }

  Future<void> _delete(Review r) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this review?',
      message: 'It disappears from the stall page and its '
          '${r.rating} star${r.rating == 1 ? '' : 's'} leave the average.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.deleteReview(r);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _reviews;
    return AlertDialog(
      title: Text('Reviews · ${widget.stall.name}'),
      content: SizedBox(
        width: 480,
        child: reviews == null
            ? const Center(
                heightFactor: 3, child: CircularProgressIndicator())
            : reviews.isEmpty
                ? const Text('No reviews.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final r in reviews)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${'★' * r.rating}${'☆' * (5 - r.rating)}  '
                              '${r.customerName?.isNotEmpty == true ? r.customerName : 'Student'}'),
                          subtitle: r.comment == null ? null : Text(r.comment!),
                          trailing: IconButton(
                            tooltip: 'Delete review',
                            icon: Icon(Icons.delete_outline,
                                color: FrColors.danger),
                            onPressed: () => _delete(r),
                          ),
                        ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}

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
            ...pending.map(_stallCard),
            const SizedBox(height: 20),
          ],
          SectionHeader('Approved (${approved.length})'),
          if (approved.isEmpty)
            const EmptyState(
              icon: Icons.storefront_outlined,
              title: 'No approved stalls yet',
            )
          else
            ...approved.map(_stallCard),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  /// One card per stall. Actions sit on their own row (not ListTile.trailing)
  /// so they wrap instead of overflowing on phones.
  Widget _stallCard(VendorWithOwner v) {
    final owner = v.ownerName.isEmpty ? v.ownerEmail : v.ownerName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: FrColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(FrRadius.md),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: v.logoUrl != null
                      ? FrImage(v.logoUrl)
                      : Icon(
                          v.isVerified
                              ? Icons.storefront
                              : Icons.pending_actions,
                          color: v.isVerified
                              ? FrColors.primary
                              : FrColors.warning),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(
                        'Owner: $owner'
                        '${owner == v.ownerEmail ? '' : ' · ${v.ownerEmail}'}',
                        style: TextStyle(
                            color: FrColors.muted, fontSize: 12.5),
                      ),
                      if (v.pickupPoint != null)
                        Text('Pickup: ${v.pickupPoint}',
                            style: TextStyle(
                                color: FrColors.muted, fontSize: 12.5)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          v.isVerified
                              ? StatusChip('Verified',
                                  color: FrColors.success)
                              : StatusChip('Pending',
                                  color: FrColors.warning),
                          v.isOpenNow
                              ? StatusChip('Open now',
                                  color: FrColors.success)
                              : StatusChip('Closed',
                                  color: FrColors.muted),
                          RatingBadge(rating: v.rating, count: v.ratingCount),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (v.isVerified)
                  TextButton(
                    onPressed: () => _setVerified(v, false),
                    child: Text('Revoke',
                        style: TextStyle(color: FrColors.danger)),
                  )
                else
                  FilledButton(
                    onPressed: () => _setVerified(v, true),
                    child: const Text('Verify'),
                  ),
                if (v.ratingCount > 0)
                  TextButton.icon(
                    onPressed: () async {
                      await showDialog<void>(
                        context: context,
                        builder: (_) => _ReviewsDialog(stall: v),
                      );
                      if (mounted) _load(); // averages may have changed
                    },
                    icon: const Icon(Icons.reviews_outlined),
                    label: Text('Reviews (${v.ratingCount})'),
                  ),
                TextButton.icon(
                  onPressed: () => _delete(v),
                  icon: Icon(Icons.delete_outline,
                      color: FrColors.danger),
                  label: Text('Delete',
                      style: TextStyle(color: FrColors.danger)),
                ),
              ],
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
      message: 'This permanently removes the stall with all its products and '
          'categories. Past orders and the owner account stay.',
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

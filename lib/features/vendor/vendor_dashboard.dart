import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/misc.dart';
import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/repository.dart';
import '../../shared/order_alerts.dart';
import '../../shared/validation.dart';
import '../../shared/widgets.dart';

/// Public reply to a review; pops with the text (empty = remove the reply).
class _ReplyDialog extends StatefulWidget {
  final String initial;
  const _ReplyDialog({required this.initial});

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reply to review'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _text,
          autofocus: true,
          maxLines: 3,
          maxLength: Limits.reply,
          decoration: const InputDecoration(
            hintText: 'Shown publicly under the review',
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final err = validateText(
              _text.text,
              max: Limits.reply,
              label: 'Reply',
            );
            if (err != null) {
              showSnack(context, err, error: true);
              return;
            }
            Navigator.pop(context, _text.text);
          },
          child: const Text('Post reply'),
        ),
      ],
    );
  }
}

class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  Vendor? _vendor;
  Map<String, dynamic>? _stats;
  List<Order> _activeOrders = [];
  List<Product> _lowStock = [];
  List<Review> _reviews = [];
  bool _loading = true;
  bool _toggling = false;
  String? _error;
  StreamSubscription<List<Order>>? _ordersSub;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final vendor = await Repository.instance.getMyVendor();
      if (vendor == null) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = ref.read(authControllerProvider).role == kRoleStaff
              ? 'You aren\'t linked to a stall yet. Ask the stall owner to add '
                    'your email under Settings → Staff, then refresh.'
              : 'No stall found for your account.';
        });
        return;
      }
      final stats = await Repository.instance.vendorStats(vendor.id);
      // Extras: the dashboard still works if either fails.
      final products = await Repository.instance
          .listProducts(vendor.id)
          .catchError((Object _) => <Product>[]);
      final reviews = await Repository.instance
          .listVendorReviews(vendor.id, limit: 5)
          .catchError((Object _) => <Review>[]);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _stats = stats;
        _lowStock =
            products
                .where(
                  (p) =>
                      p.isAvailable &&
                      p.stockQty != null &&
                      p.stockQty! <= kLowStockThreshold,
                )
                .toList()
              ..sort((a, b) => a.stockQty!.compareTo(b.stockQty!));
        _reviews = reviews;
        _loading = false;
        _error = null;
      });

      // Live orders stream keeps the active list real-time.
      _ordersSub ??= Repository.instance.streamVendorOrders(vendor.id).listen((
        orders,
      ) {
        if (!mounted) return;
        setState(() {
          _activeOrders = orders.where((o) => o.isActive).toList();
        });
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  Future<void> _toggleOpen(bool value) async {
    final v = _vendor;
    if (v == null) return;
    setState(() => _toggling = true);
    try {
      await Repository.instance.updateMyVendor(
        vendorId: v.id,
        name: v.name,
        description: v.description,
        gcashNumber: v.gcashNumber,
        gcashName: v.gcashName,
        pickupPoint: v.pickupPoint,
        isOpen: value,
      );
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, 'Could not update: $e', error: true);
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _vendor == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _vendor == null) {
      return FrPage(
        title: 'Dashboard',
        children: [
          EmptyState(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: _error,
            action: FilledButton(onPressed: _load, child: const Text('Retry')),
          ),
        ],
      );
    }

    final v = _vendor!;
    final isOwner = ref.watch(authControllerProvider).role == kRoleVendor;
    return FrPage(
      title: 'Dashboard',
      subtitle: v.name,
      actions: [
        if (!isOwner)
          StatusChip(
            v.isOpen ? 'OPEN' : 'CLOSED',
            color: v.isOpen ? FrColors.success : FrColors.muted,
          )
        else
          _toggling
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(),
                  ),
                )
              : Row(
                  children: [
                    Text(
                      v.isOpen ? 'OPEN' : 'CLOSED',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: v.isOpen ? FrColors.success : FrColors.muted,
                      ),
                    ),
                    Switch(value: v.isOpen, onChanged: _toggleOpen),
                  ],
                ),
      ],
      children: [
        if (!v.isVerified)
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: FrColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(FrRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.hourglass_top, color: FrColors.warning),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your stall is pending admin verification. You can set up '
                    'your menu meanwhile — customers will see you once verified.',
                  ),
                ),
              ],
            ),
          ),

        _statusCard(v),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, c) {
            final twoCol = c.maxWidth > 720;
            final cards = [
              (
                'Orders today',
                '${_stats?['ordersToday'] ?? 0}',
                Icons.receipt_long,
                FrColors.primary,
              ),
              (
                'Active now',
                '${_stats?['active'] ?? 0}',
                Icons.local_fire_department,
                FrColors.secondary,
              ),
              (
                'Revenue today',
                peso(_stats?['revenueToday'] ?? 0),
                Icons.payments,
                FrColors.success,
              ),
            ];
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _stat(cards[0])),
                    const SizedBox(width: 12),
                    Expanded(child: _stat(cards[1])),
                    if (twoCol) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _stat(cards[2])),
                    ],
                  ],
                ),
                if (!twoCol) ...[const SizedBox(height: 12), _stat(cards[2])],
              ],
            );
          },
        ),

        const SizedBox(height: 12),
        SectionHeader('Active orders'),
        if (_activeOrders.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'All caught up!',
            message: 'No active orders right now.',
          )
        else
          ..._activeOrders
              .take(5)
              .map(
                (o) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => context.go('/vendor/orders'),
                    title: Text(
                      '#${o.queueNumber ?? '?'} · ${o.customerName ?? 'Customer'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${o.orderNumber} · ${kOrderStatusLabels[o.status] ?? o.status}',
                    ),
                    trailing: Text(
                      peso(o.total),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
        if (_lowStock.isNotEmpty) ...[
          const SizedBox(height: 12),
          SectionHeader(
            'Running low',
            trailing: TextButton(
              onPressed: () => context.go('/vendor/menu'),
              child: const Text('Restock'),
            ),
          ),
          Card(
            child: Column(
              children: [
                for (final p in _lowStock)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.inventory_2_outlined,
                      color: FrColors.danger,
                    ),
                    title: Text(
                      p.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Text(
                      p.stockQty == 0 ? 'Sold out' : '${p.stockQty} left',
                      style: TextStyle(
                        color: FrColors.danger,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        const SectionHeader('Recent reviews'),
        if (_reviews.isEmpty)
          Text(
            'No reviews yet. Students can rate you after pickup.',
            style: TextStyle(color: FrColors.muted),
          )
        else
          for (final r in _reviews) _reviewTile(r),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _reviewTile(Review r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  Icon(
                    i <= r.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 18,
                    color: FrColors.warning,
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.customerName?.isNotEmpty == true
                        ? r.customerName!
                        : 'Student',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (ref.watch(authControllerProvider).role == kRoleVendor)
                  TextButton(
                    onPressed: () => _reply(r),
                    child: Text(r.reply == null ? 'Reply' : 'Edit reply'),
                  ),
              ],
            ),
            if (r.comment != null) Text(r.comment!),
            if (r.reply != null) ...[
              const SizedBox(height: 6),
              Text(
                'Your reply: ${r.reply}',
                style: TextStyle(color: FrColors.muted, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _reply(Review r) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => _ReplyDialog(initial: r.reply ?? ''),
    );
    if (text == null) return;
    try {
      await Repository.instance.replyToReview(r.id, text);
      final reviews = await Repository.instance.listVendorReviews(
        _vendor!.id,
        limit: 5,
      );
      if (!mounted) return;
      setState(() => _reviews = reviews);
      showSnack(
        context,
        text.trim().isEmpty ? 'Reply removed.' : 'Reply posted.',
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not save reply: $e', error: true);
    }
  }

  /// What students see right now, plus rating and alert opt-in.
  Widget _statusCard(Vendor v) {
    final now = DateTime.now();
    final openNow = v.isOpenNow;
    final hours = v.hoursLabel(now);
    final String headline;
    if (openNow) {
      headline = 'Students can order now${hours == null ? '' : ' · $hours'}';
    } else if (v.isOpen) {
      headline =
          'Outside your opening hours'
          '${hours == null ? '' : ' · $hours'}';
    } else {
      headline = 'Closed: switch on to take orders';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  openNow ? Icons.storefront : Icons.schedule,
                  color: openNow ? FrColors.success : FrColors.muted,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    headline,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            RatingBadge(rating: v.rating, count: v.ratingCount, size: 14),
            const EnableAlertsButton(label: 'Alert me about new orders'),
            OutlinedButton.icon(
              onPressed: () => context.go('/display'),
              icon: const Icon(Icons.tv),
              label: const Text('"Now serving" screen'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat((String, String, IconData, Color) s) {
    return StatCard(label: s.$1, value: s.$2, icon: s.$3, color: s.$4);
  }
}

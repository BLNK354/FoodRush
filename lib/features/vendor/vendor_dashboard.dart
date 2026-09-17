import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class VendorDashboard extends ConsumerStatefulWidget {
  const VendorDashboard({super.key});

  @override
  ConsumerState<VendorDashboard> createState() => _VendorDashboardState();
}

class _VendorDashboardState extends ConsumerState<VendorDashboard> {
  Vendor? _vendor;
  Map<String, dynamic>? _stats;
  List<Order> _activeOrders = [];
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
          _error = 'No stall found for your account.';
        });
        return;
      }
      final stats = await Repository.instance.vendorStats(vendor.id);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _stats = stats;
        _loading = false;
        _error = null;
      });

      // Live orders stream keeps the active list real-time.
      _ordersSub ??= Repository.instance
          .streamVendorOrders(vendor.id)
          .listen((orders) {
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
    return FrPage(
      title: 'Dashboard',
      subtitle: v.name,
      actions: [
        _toggling
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator()),
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
                  Switch(
                    value: v.isOpen,
                    onChanged: _toggleOpen,
                  ),
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
            child: const Row(
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

        LayoutBuilder(builder: (context, c) {
          final twoCol = c.maxWidth > 720;
          final cards = [
            ('Orders today', '${_stats?['ordersToday'] ?? 0}',
                Icons.receipt_long, FrColors.primary),
            ('Active now', '${_stats?['active'] ?? 0}',
                Icons.local_fire_department, FrColors.secondary),
            ('Revenue today', peso(_stats?['revenueToday'] ?? 0),
                Icons.payments, FrColors.success),
          ];
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _stat(cards[0]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _stat(cards[1]),
                  ),
                  if (twoCol) ...[
                    const SizedBox(width: 12),
                    Expanded(child: _stat(cards[2])),
                  ],
                ],
              ),
              if (!twoCol) ...[
                const SizedBox(height: 12),
                _stat(cards[2]),
              ],
            ],
          );
        }),

        const SizedBox(height: 12),
        SectionHeader('Active orders'),
        if (_activeOrders.isEmpty)
          const EmptyState(
            icon: Icons.check_circle_outline,
            title: 'All caught up!',
            message: 'No active orders right now.',
          )
        else
          ..._activeOrders.take(5).map(
                (o) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    onTap: () => context.go('/vendor/orders'),
                    title: Text(
                      '#${o.queueNumber ?? '?'} · ${o.customerName ?? 'Customer'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                        '${o.orderNumber} · ${kOrderStatusLabels[o.status] ?? o.status}'),
                    trailing: Text(peso(o.total),
                        style: const TextStyle(fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _stat((String, String, IconData, Color) s) {
    return StatCard(label: s.$1, value: s.$2, icon: s.$3, color: s.$4);
  }
}

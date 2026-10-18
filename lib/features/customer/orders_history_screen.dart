import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/i18n.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/auth_controller.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';
import 'reorder.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() =>
      _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  List<Order>? _orders;
  StreamSubscription<List<Order>>? _sub;

  /// Past orders beyond the live newest-200, fetched with "Load older".
  List<Order> _older = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  Future<void> _loadOlder() async {
    final all = [...?_orders, ..._older];
    final uid = ref.read(authControllerProvider).profile?.id;
    final oldest = all
        .map((o) => o.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (m, d) => m == null || d.isBefore(m) ? d : m);
    if (oldest == null || uid == null) return;
    setState(() => _loadingOlder = true);
    try {
      final more = await Repository.instance
          .olderOrders(field: 'customerId', value: uid, before: oldest);
      if (!mounted) return;
      setState(() {
        _older = [..._older, ...more];
        _noMoreOlder = more.length < 50;
      });
    } catch (e) {
      if (mounted) showSnack(context, 'Could not load older orders: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // Live stream — history updates in real time.
    _sub = Repository.instance.streamMyOrders().listen((orders) {
      if (!mounted) return;
      setState(() => _orders = orders);
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _orders = []);
      showSnack(context, 'Could not load orders: $e', error: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orders = _orders;

    return FrPage(
      title: tr('My orders'),
      subtitle: tr('Track your pickups and review past orders.'),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.sync),
          tooltip: 'Live — updates automatically',
        ),
      ],
      children: [
        if (orders == null)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (orders.isEmpty)
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: tr('No orders yet'),
            message: tr('Your order history will appear here.'),
          )
        else ...[
          _OrderSection(
            title: tr('Active'),
            orders: orders
                .where((o) => o.isActive)
                .toList(),
            emptyText: 'No active orders. Hungry?',
          ),
          const SizedBox(height: 24),
          _OrderSection(
            title: tr('Past'),
            orders: [...orders, ..._older]
                .where((o) => !o.isActive)
                .toList(),
            emptyText: 'Nothing here yet.',
          ),
          if (!_noMoreOlder && orders.length >= 20)
            Center(
              child: TextButton.icon(
                onPressed: _loadingOlder ? null : _loadOlder,
                icon: const Icon(Icons.history),
                label: Text(_loadingOlder ? 'Loading…' : 'Load older orders'),
              ),
            ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _OrderSection extends StatelessWidget {
  final String title;
  final List<Order> orders;
  final String emptyText;

  const _OrderSection({
    required this.title,
    required this.orders,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title),
        if (orders.isEmpty)
          Text(emptyText, style: TextStyle(color: FrColors.muted))
        else
          ...orders.map((o) => _OrderCard(order: o)),
      ],
    );
  }
}

class _OrderCard extends ConsumerWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final created = order.createdAt;
    final dateStr = created == null
        ? ''
        : '${created.month}/${created.day} ${created.hour}:${created.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.go('/orders/${order.id}'),
        borderRadius: BorderRadius.circular(FrRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.vendorName ?? 'Stall',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip.order(order.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.orderNumber} · $dateStr · '
                      '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                      style: TextStyle(
                          color: FrColors.muted, fontSize: 12.5),
                    ),
                    if (order.refundStatus != null) ...[
                      const SizedBox(height: 6),
                      order.refundOwed
                          ? StatusChip('Refund pending: ${peso(order.total)}',
                              color: FrColors.warning)
                          : StatusChip('Refunded',
                              color: FrColors.success),
                    ],
                    if (order.isActive) ...[
                      const SizedBox(height: 10),
                      OrderProgressBar(
                          status: order.status,
                          paymentMethod: order.paymentMethod),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(peso(order.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                  if (order.queueNumber != null && order.isActive)
                    Text(tr('Queue #{n}', {'n': order.queueNumber}),
                        style: TextStyle(
                            color: FrColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                ],
              ),
              const SizedBox(width: 8),
              if (order.isActive &&
                  (order.status == kOrderAwaitingPayment ||
                      order.status == kOrderProofSubmitted))
                IconButton(
                  tooltip: tr('Cancel order'),
                  icon: Icon(Icons.close, color: FrColors.muted),
                  onPressed: () => _cancel(context, ref),
                ),
              if (!order.isActive)
                IconButton(
                  tooltip: tr('Order again'),
                  icon: Icon(Icons.replay, color: FrColors.primary),
                  onPressed: () => reorder(context, ref, order),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: tr('Cancel this order?'),
      message: order.status == kOrderProofSubmitted
          ? 'This cannot be undone. You already sent payment, so the stall '
              'will owe you a ${peso(order.total)} refund. You can follow it here.'
          : 'This cannot be undone.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.cancelOrder(order.id);
      if (context.mounted) showSnack(context, tr('Order cancelled'));
    } catch (e) {
      if (context.mounted) showSnack(context, 'Cancel failed: $e', error: true);
    }
  }
}

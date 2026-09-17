import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class OrdersHistoryScreen extends ConsumerStatefulWidget {
  const OrdersHistoryScreen({super.key});

  @override
  ConsumerState<OrdersHistoryScreen> createState() =>
      _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends ConsumerState<OrdersHistoryScreen> {
  List<Order>? _orders;
  StreamSubscription<List<Order>>? _sub;

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
      title: 'My orders',
      subtitle: 'Track your pickups and review past orders.',
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
          const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No orders yet',
            message: 'Your order history will appear here.',
          )
        else ...[
          _OrderSection(
            title: 'Active',
            orders: orders
                .where((o) => o.isActive)
                .toList(),
            emptyText: 'No active orders. Hungry?',
          ),
          const SizedBox(height: 24),
          _OrderSection(
            title: 'Past',
            orders: orders
                .where((o) => !o.isActive)
                .toList(),
            emptyText: 'Nothing here yet.',
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
          Text(emptyText, style: const TextStyle(color: FrColors.muted))
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
                      style: const TextStyle(
                          color: FrColors.muted, fontSize: 12.5),
                    ),
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
                    Text('Queue #${order.queueNumber}',
                        style: const TextStyle(
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
                  tooltip: 'Cancel order',
                  icon: const Icon(Icons.close, color: FrColors.muted),
                  onPressed: () => _cancel(context, ref),
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
      title: 'Cancel this order?',
      message: 'This cannot be undone. If you already paid via GCash, '
          'coordinate with the stall for a refund.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (!ok) return;
    try {
      await Repository.instance.cancelOrder(order.id);
      if (context.mounted) showSnack(context, 'Order cancelled');
    } catch (e) {
      if (context.mounted) showSnack(context, 'Cancel failed: $e', error: true);
    }
  }
}

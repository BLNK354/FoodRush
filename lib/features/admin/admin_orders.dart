import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
import '../../shared/widgets.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String _filter = 'all';
  final Set<String> _expanded = {};
  StreamSubscription<List<Order>>? _sub;

  @override
  void initState() {
    super.initState();
    // Live stream — every order across the platform, updating in real time.
    _sub = Repository.instance.streamAllOrders().listen((orders) {
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    }, onError: (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showSnack(context, 'Could not load orders: $e', error: true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// Orders beyond the live newest-300, fetched with "Load older".
  List<Order> _older = [];
  bool _loadingOlder = false;
  bool _noMoreOlder = false;

  Future<void> _loadOlder() async {
    final oldest = [..._orders, ..._older]
        .map((o) => o.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (m, d) => m == null || d.isBefore(m) ? d : m);
    if (oldest == null) return;
    setState(() => _loadingOlder = true);
    try {
      final more = await Repository.instance.olderOrders(before: oldest);
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

  List<Order> get _filtered {
    final all = [..._orders, ..._older];
    switch (_filter) {
      case 'active':
        return all.where((o) => o.isActive).toList();
      case 'gcash':
        return all
            .where((o) => o.paymentMethod == kPayGcash)
            .toList();
      case 'completed':
        return all.where((o) => o.status == kOrderCompleted).toList();
      case 'refunds':
        return all.where((o) => o.refundOwed).toList();
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FrPage(
      title: 'Orders',
      subtitle: 'Every order across the platform.',
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.sync),
          tooltip: 'Live — updates automatically',
        ),
      ],
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in const [
              ('all', 'All'),
              ('active', 'Active'),
              ('gcash', 'GCash'),
              ('completed', 'Completed'),
              ('refunds', 'Refunds owed'),
            ])
              ChoiceChip(
                label: Text(f.$2),
                selected: _filter == f.$1,
                onSelected: (_) => setState(() => _filter = f.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading && _orders.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_filtered.isEmpty)
          const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders')
        else
          ..._filtered.map(_orderTile),
        if (_orders.length >= 300 && !_noMoreOlder)
          Center(
            child: TextButton.icon(
              onPressed: _loadingOlder ? null : _loadOlder,
              icon: const Icon(Icons.history),
              label: Text(_loadingOlder ? 'Loading…' : 'Load older orders'),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _orderTile(Order o) {
    final open = _expanded.contains(o.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              open ? _expanded.remove(o.id) : _expanded.add(o.id);
            }),
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
                                '${o.orderNumber} · ${o.vendorName ?? ''}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusChip.order(o.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${o.customerName ?? 'Customer'} · '
                          '${o.paymentMethod.toUpperCase()} · '
                          '${_fmt(o.createdAt)}',
                          style: TextStyle(
                              color: FrColors.muted, fontSize: 12.5),
                        ),
                        if (o.isActive) ...[
                          const SizedBox(height: 8),
                          OrderProgressBar(
                              status: o.status,
                              paymentMethod: o.paymentMethod),
                        ],
                      ],
                    ),
                  ),
                  Text(peso(o.total),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 15)),
                  Icon(open
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  ...o.items.map(
                    (it) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(child: Text('${it.qty} × ${it.label}')),
                          Text(peso(it.lineTotal)),
                        ],
                      ),
                    ),
                  ),
                  if (o.note != null && o.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Note: ${o.note}',
                          style: TextStyle(
                              fontStyle: FontStyle.italic,
                              color: FrColors.muted,
                              fontSize: 12.5)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.month}/${d.day}/${d.year}';
  }
}

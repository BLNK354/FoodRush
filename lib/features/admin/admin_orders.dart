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

  List<Order> get _filtered {
    switch (_filter) {
      case 'active':
        return _orders.where((o) => o.isActive).toList();
      case 'gcash':
        return _orders
            .where((o) => o.paymentMethod == kPayGcash)
            .toList();
      case 'completed':
        return _orders.where((o) => o.status == kOrderCompleted).toList();
      default:
        return _orders;
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
          children: [
            for (final f in const [
              ('all', 'All'),
              ('active', 'Active'),
              ('gcash', 'GCash'),
              ('completed', 'Completed'),
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
                          style: const TextStyle(
                              color: FrColors.muted, fontSize: 12.5),
                        ),
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
                          Expanded(child: Text('${it.qty} × ${it.name}')),
                          Text(peso(it.lineTotal)),
                        ],
                      ),
                    ),
                  ),
                  if (o.note != null && o.note!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Note: ${o.note}',
                          style: const TextStyle(
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

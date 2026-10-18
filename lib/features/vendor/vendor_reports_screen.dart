import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/sales_report.dart';
import '../../shared/widgets.dart';

/// Sales over the last 7 or 30 days: headline tiles, a revenue-per-day bar
/// chart, best sellers, and a CSV export of every order in the range.
/// Revenue counts COMPLETED orders only (picked up and paid).
class VendorReportsScreen extends ConsumerStatefulWidget {
  const VendorReportsScreen({super.key});

  @override
  ConsumerState<VendorReportsScreen> createState() =>
      _VendorReportsScreenState();
}

class _VendorReportsScreenState extends ConsumerState<VendorReportsScreen> {
  Vendor? _vendor;
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final vendor = await Repository.instance.getMyVendor();
      final orders = vendor == null
          ? <Order>[]
          : await Repository.instance.listVendorOrders(vendor.id);
      if (!mounted) return;
      setState(() {
        _vendor = vendor;
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  DateTime get _start {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
  }

  List<Order> get _inRange => _orders
      .where((o) => o.createdAt != null && !o.createdAt!.isBefore(_start))
      .toList()
    ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _vendor == null) {
      return FrPage(title: 'Reports', children: [
        EmptyState(
          icon: Icons.error_outline,
          title: _vendor == null && _error == null
              ? 'No stall found'
              : 'Could not load reports',
          message: _error,
          action: FilledButton(onPressed: _load, child: const Text('Retry')),
        ),
      ]);
    }

    final orders = _inRange;
    final r = SalesReport.from(orders, _start, _days);

    return FrPage(
      title: 'Reports',
      subtitle: 'Revenue counts completed (picked-up) orders.',
      actions: [
        IconButton(
            tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
      ],
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Last 7 days')),
                ButtonSegment(value: 30, label: Text('Last 30 days')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            OutlinedButton.icon(
              onPressed: orders.isEmpty ? null : () => _exportCsv(orders),
              icon: const Icon(Icons.download),
              label: const Text('Download CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 900 ? 4 : 2;
          final tiles = [
            StatCard(
                label: 'Revenue',
                value: peso(r.revenue),
                icon: Icons.payments,
                color: FrColors.success),
            StatCard(
                label: 'Completed orders',
                value: '${r.completed}',
                icon: Icons.receipt_long,
                color: FrColors.primary),
            StatCard(
                label: 'Average order',
                value: r.completed == 0 ? '—' : peso(r.revenue / r.completed),
                icon: Icons.shopping_basket,
                color: FrColors.info),
            StatCard(
                label: 'Cancelled / rejected',
                value: '${r.lost}',
                icon: Icons.block,
                color: FrColors.muted),
          ];
          return GridView.count(
            crossAxisCount: cols,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: cols == 4 ? 2.2 : 1.7,
            children: tiles,
          );
        }),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Revenue per day',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  'GCash ${peso(r.gcashRevenue)} · Cash ${peso(r.cashRevenue)}',
                  style: TextStyle(color: FrColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: RevenueChart(days: r.daily)),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('Show as table',
                      style: TextStyle(fontSize: 13.5)),
                  children: [
                    for (final d in r.daily.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Expanded(child: Text(dayLabel(d.day))),
                            SizedBox(
                              width: 90,
                              child: Text('${d.orders} orders',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                      color: FrColors.muted)),
                            ),
                            SizedBox(
                              width: 110,
                              child: Text(peso(d.revenue),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader('Best sellers'),
        if (r.topItems.isEmpty)
          const EmptyState(
            icon: Icons.insights_outlined,
            title: 'No completed orders yet',
            message: 'Best sellers appear once orders are picked up.',
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final (i, item) in r.topItems.indexed)
                    ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            FrColors.primary.withValues(alpha: 0.1),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: FrColors.primary)),
                      ),
                      title: Text(item.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${item.qty} sold'),
                      trailing: Text(peso(item.revenue),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  void _exportCsv(List<Order> orders) {
    final s = _start;
    final name = (_vendor?.name ?? 'stall')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    downloadOrdersCsv(
        'foodrush-$name-${s.year}${two2(s.month)}${two2(s.day)}-${_days}d.csv',
        orders);
  }
}

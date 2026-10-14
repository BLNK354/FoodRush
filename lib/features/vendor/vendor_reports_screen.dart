import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/repository.dart';
import '../../shared/browser/browser.dart' as browser;
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
    final r = _Report.from(orders, _start, _days);

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
                  style: const TextStyle(color: FrColors.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                SizedBox(height: 200, child: _RevenueChart(days: r.daily)),
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
                            Expanded(child: Text(_dayLabel(d.day))),
                            SizedBox(
                              width: 90,
                              child: Text('${d.orders} orders',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
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
                            style: const TextStyle(
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
    String cell(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String stamp(DateTime? t) => t == null
        ? ''
        : '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

    final rows = <List<Object?>>[
      [
        'Order', 'Queue', 'Placed', 'Pickup', 'Customer', 'Status', 'Payment',
        'Items', 'Subtotal', 'Discount', 'Total', 'Promo',
      ],
      for (final o in orders)
        [
          o.orderNumber,
          o.queueNumber,
          stamp(o.createdAt),
          o.pickupAt == null ? 'ASAP' : stamp(o.pickupAt),
          o.customerName,
          kOrderStatusLabels[o.status] ?? o.status,
          o.paymentMethod,
          o.items.map((i) => '${i.qty}x ${i.name}').join('; '),
          o.subtotal.toStringAsFixed(2),
          o.discount.toStringAsFixed(2),
          o.total.toStringAsFixed(2),
          o.promoCode,
        ],
    ];
    final csv = rows.map((r) => r.map(cell).join(',')).join('\r\n');
    final s = _start;
    final name = (_vendor?.name ?? 'stall')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    browser.downloadTextFile(
      'foodrush-$name-${s.year}${_two(s.month)}${_two(s.day)}-${_days}d.csv',
      // BOM so Excel opens the peso sign / names as UTF-8.
      '﻿$csv',
      mimeType: 'text/csv',
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _dayLabel(DateTime d) =>
    '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]} '
    '${_months[d.month - 1]} ${d.day}';

class _DayTotal {
  final DateTime day;
  double revenue = 0;
  int orders = 0;
  _DayTotal(this.day);
}

class _ItemTotal {
  final String name;
  int qty = 0;
  double revenue = 0;
  _ItemTotal(this.name);
}

/// Everything the page shows, computed once per build from the range.
class _Report {
  double revenue = 0, gcashRevenue = 0, cashRevenue = 0;
  int completed = 0, lost = 0;
  final List<_DayTotal> daily;
  List<_ItemTotal> topItems = [];

  _Report._(this.daily);

  factory _Report.from(List<Order> orders, DateTime start, int days) {
    final r = _Report._([
      for (var i = 0; i < days; i++)
        _DayTotal(DateTime(start.year, start.month, start.day + i)),
    ]);
    final items = <String, _ItemTotal>{};
    for (final o in orders) {
      if (o.status == kOrderCancelled || o.status == kOrderRejected) {
        r.lost++;
        continue;
      }
      if (o.status != kOrderCompleted) continue;
      r.completed++;
      r.revenue += o.total;
      if (o.paymentMethod == kPayGcash) {
        r.gcashRevenue += o.total;
      } else {
        r.cashRevenue += o.total;
      }
      final c = o.createdAt!;
      final idx = DateTime(c.year, c.month, c.day)
          .difference(r.daily.first.day)
          .inDays;
      if (idx >= 0 && idx < r.daily.length) {
        r.daily[idx].revenue += o.total;
        r.daily[idx].orders++;
      }
      for (final it in o.items) {
        final t = items.putIfAbsent(it.productId, () => _ItemTotal(it.name));
        t.qty += it.qty;
        t.revenue += it.lineTotal;
      }
    }
    r.topItems = items.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    if (r.topItems.length > 10) r.topItems = r.topItems.sublist(0, 10);
    return r;
  }
}

/// Single-series bar chart: thin bars with 4px rounded tops on a baseline,
/// a recessive max gridline, sparse date labels, and a tooltip per bar
/// (hover on desktop, long-press on touch).
class _RevenueChart extends StatelessWidget {
  final List<_DayTotal> days;
  const _RevenueChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final max = days.fold<double>(0, (m, d) => d.revenue > m ? d.revenue : m);
    final labelEvery = days.length <= 7 ? 1 : 5;
    const grid = Color(0x1F000000);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(max == 0 ? 'No completed orders in this range' : peso(max),
            style: const TextStyle(color: FrColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: grid),
                bottom: BorderSide(color: Color(0x40000000)),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Tooltip(
                      message: '${_dayLabel(d.day)}\n${peso(d.revenue)} · '
                          '${d.orders} order${d.orders == 1 ? '' : 's'}',
                      // Full-height hit target, wider than the thin bar.
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.symmetric(
                            horizontal: days.length <= 7 ? 14 : 2),
                        child: FractionallySizedBox(
                          heightFactor: max == 0 ? 0 : d.revenue / max,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: FrColors.primary,
                              borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, d) in days.indexed)
              Expanded(
                child: Text(
                  i % labelEvery == 0 || i == days.length - 1
                      ? (days.length <= 7
                          ? _dayLabel(d.day).split(' ').first
                          : '${d.day.month}/${d.day.day}')
                      : '',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: const TextStyle(color: FrColors.muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

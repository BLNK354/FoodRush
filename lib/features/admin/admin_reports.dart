import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/order.dart';
import '../../providers/repository.dart';
import '../../shared/sales_report.dart';
import '../../shared/widgets.dart';

/// Platform-wide sales: totals, revenue per day, revenue by stall, busiest
/// hours, and a CSV of every order in the range.
class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  int _days = 7;
  List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _start {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: _days - 1));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await Repository.instance.listOrdersSince(_start);
      if (!mounted) return;
      setState(() {
        _orders = orders
            .where((o) => o.createdAt != null)
            .toList()
          ..sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
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

  @override
  Widget build(BuildContext context) {
    final r = SalesReport.from(_orders, _start, _days);
    final s = _start;

    return FrPage(
      title: 'Reports',
      subtitle: 'All stalls. Revenue counts completed (picked-up) orders.',
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
              onSelectionChanged: (sel) {
                setState(() => _days = sel.first);
                _load(); // a longer range needs more orders
              },
            ),
            OutlinedButton.icon(
              onPressed: _orders.isEmpty
                  ? null
                  : () => downloadOrdersCsv(
                      'foodrush-all-${s.year}${two2(s.month)}${two2(s.day)}-${_days}d.csv',
                      _orders,
                      includeStall: true),
              icon: const Icon(Icons.download),
              label: const Text('Download CSV'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator()))
        else if (_error != null)
          EmptyState(
            icon: Icons.error_outline,
            title: 'Could not load reports',
            message: _error,
            action: FilledButton(onPressed: _load, child: const Text('Retry')),
          )
        else ...[
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: cols == 4 ? 2.2 : 1.7,
              children: [
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
                    value:
                        r.completed == 0 ? '—' : peso(r.revenue / r.completed),
                    icon: Icons.shopping_basket,
                    color: FrColors.info),
                StatCard(
                    label: 'Cancelled / rejected',
                    value: '${r.lost}',
                    icon: Icons.block,
                    color: FrColors.muted),
              ],
            );
          }),
          const SizedBox(height: 20),
          _chartCard('Revenue per day',
              'GCash ${peso(r.gcashRevenue)} · Cash ${peso(r.cashRevenue)}',
              RevenueChart(days: r.daily)),
          const SizedBox(height: 20),
          _chartCard(
            'Busiest hours',
            'Completed orders by the hour they were placed',
            SimpleBarChart(
              values: [for (final n in r.byHour) n.toDouble()],
              maxLabel: (m) => '${m.round()} orders',
              emptyText: 'No completed orders in this range',
              tooltips: [
                for (final (h, n) in r.byHour.indexed)
                  '${_hour(h)}–${_hour(h + 1)}\n$n order${n == 1 ? '' : 's'}',
              ],
              labels: [
                for (var h = 0; h < 24; h++) h % 3 == 0 ? _hour(h) : '',
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader('Revenue by stall'),
          if (r.byStall.isEmpty)
            const EmptyState(
                icon: Icons.storefront_outlined,
                title: 'No completed orders yet')
          else
            Card(
              child: Column(
                children: [
                  for (final e in r.byStall)
                    ListTile(
                      dense: true,
                      title: Text(e.key,
                          style:
                              const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: LinearProgressIndicator(
                        value: r.revenue == 0 ? 0 : e.value / r.revenue,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      trailing: Text(peso(e.value),
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 40),
        ],
      ],
    );
  }

  static String _hour(int h) {
    final hh = h % 24;
    final h12 = hh % 12 == 0 ? 12 : hh % 12;
    return '$h12${hh < 12 ? 'a' : 'p'}';
  }

  Widget _chartCard(String title, String subtitle, Widget chart) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title,
                  style:
                      const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Text(subtitle,
                  style: TextStyle(color: FrColors.muted, fontSize: 12.5)),
              const SizedBox(height: 16),
              SizedBox(height: 200, child: chart),
            ],
          ),
        ),
      );
}

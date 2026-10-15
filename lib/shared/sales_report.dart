import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/order.dart';
import 'browser/browser.dart' as browser;
import 'widgets.dart';

/// Zero-padded two digits.
String two2(int n) => n.toString().padLeft(2, '0');

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String dayLabel(DateTime d) =>
    '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][d.weekday - 1]} '
    '${_months[d.month - 1]} ${d.day}';

class DayTotal {
  final DateTime day;
  double revenue = 0;
  int orders = 0;
  DayTotal(this.day);
}

class ItemTotal {
  final String name;
  int qty = 0;
  double revenue = 0;
  ItemTotal(this.name);
}

/// Everything a sales report shows, computed once from the orders in a
/// date range. Revenue counts COMPLETED orders only.
class SalesReport {
  double revenue = 0, gcashRevenue = 0, cashRevenue = 0;
  int completed = 0, lost = 0;
  final List<DayTotal> daily;
  List<ItemTotal> topItems = [];

  /// Completed-order revenue per stall name, highest first (admin view).
  List<MapEntry<String, double>> byStall = [];

  /// Completed orders placed in each hour of the day (0-23).
  final List<int> byHour = List.filled(24, 0);

  SalesReport._(this.daily);

  factory SalesReport.from(List<Order> orders, DateTime start, int days) {
    final r = SalesReport._([
      for (var i = 0; i < days; i++)
        DayTotal(DateTime(start.year, start.month, start.day + i)),
    ]);
    final items = <String, ItemTotal>{};
    final stalls = <String, double>{};
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
      stalls[o.vendorName ?? o.vendorId] =
          (stalls[o.vendorName ?? o.vendorId] ?? 0) + o.total;
      final c = o.createdAt!;
      r.byHour[c.hour]++;
      final idx = DateTime(c.year, c.month, c.day)
          .difference(r.daily.first.day)
          .inDays;
      if (idx >= 0 && idx < r.daily.length) {
        r.daily[idx].revenue += o.total;
        r.daily[idx].orders++;
      }
      for (final it in o.items) {
        final t = items.putIfAbsent(it.productId, () => ItemTotal(it.name));
        t.qty += it.qty;
        t.revenue += it.lineTotal;
      }
    }
    r.topItems = items.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));
    if (r.topItems.length > 10) r.topItems = r.topItems.sublist(0, 10);
    r.byStall = stalls.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return r;
  }
}

/// Revenue per day for a report range.
class RevenueChart extends StatelessWidget {
  final List<DayTotal> days;
  const RevenueChart({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    final short = days.length <= 7;
    return SimpleBarChart(
      values: [for (final d in days) d.revenue],
      maxLabel: peso,
      emptyText: 'No completed orders in this range',
      tooltips: [
        for (final d in days)
          '${dayLabel(d.day)}\n${peso(d.revenue)} · '
              '${d.orders} order${d.orders == 1 ? '' : 's'}',
      ],
      labels: [
        for (final (i, d) in days.indexed)
          short || i % 5 == 0 || i == days.length - 1
              ? (short
                  ? dayLabel(d.day).split(' ').first
                  : '${d.day.month}/${d.day.day}')
              : '',
      ],
      barPadding: short ? 14 : 2,
    );
  }
}

/// Single-series bar chart: thin bars with 4px rounded tops on a baseline,
/// a recessive max gridline, sparse labels, and a tooltip per bar (hover on
/// desktop, long-press on touch). One series, so no legend: the card title
/// names it.
class SimpleBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels; // '' = no label under that bar
  final List<String> tooltips;
  final String Function(double max) maxLabel;
  final String emptyText;
  final double barPadding;

  const SimpleBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.tooltips,
    required this.maxLabel,
    required this.emptyText,
    this.barPadding = 2,
  });

  @override
  Widget build(BuildContext context) {
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final grid = FrColors.muted.withValues(alpha: 0.18);
    final baseline = FrColors.muted.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(max == 0 ? emptyText : maxLabel(max),
            style: TextStyle(color: FrColors.muted, fontSize: 11)),
        const SizedBox(height: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: grid),
                bottom: BorderSide(color: baseline),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, v) in values.indexed)
                  Expanded(
                    child: Tooltip(
                      message: tooltips[i],
                      // Full-height hit target, wider than the thin bar.
                      child: Container(
                        color: Colors.transparent,
                        alignment: Alignment.bottomCenter,
                        padding: EdgeInsets.symmetric(horizontal: barPadding),
                        child: FractionallySizedBox(
                          heightFactor: max == 0 ? 0 : v / max,
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
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.visible,
                  softWrap: false,
                  style: TextStyle(color: FrColors.muted, fontSize: 11),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Downloads [orders] as a CSV (Excel-friendly UTF-8) named [fileName].
void downloadOrdersCsv(String fileName, List<Order> orders,
    {bool includeStall = false}) {
  String cell(Object? v) {
    final s = '${v ?? ''}';
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  String stamp(DateTime? t) => t == null
      ? ''
      : '${t.year}-${two2(t.month)}-${two2(t.day)} ${two2(t.hour)}:${two2(t.minute)}';

  final rows = <List<Object?>>[
    [
      'Order', if (includeStall) 'Stall', 'Queue', 'Placed', 'Pickup',
      'Customer', 'Status', 'Payment', 'Items', 'Subtotal', 'Discount',
      'Total', 'Promo', 'Refund',
    ],
    for (final o in orders)
      [
        o.orderNumber,
        if (includeStall) o.vendorName,
        o.queueNumber,
        stamp(o.createdAt),
        o.pickupAt == null ? 'ASAP' : stamp(o.pickupAt),
        o.customerName,
        kOrderStatusLabels[o.status] ?? o.status,
        o.paymentMethod,
        o.items.map((i) => '${i.qty}x ${i.label}').join('; '),
        o.subtotal.toStringAsFixed(2),
        o.discount.toStringAsFixed(2),
        o.total.toStringAsFixed(2),
        o.promoCode,
        o.refundStatus,
      ],
  ];
  final csv = rows.map((r) => r.map(cell).join(',')).join('\r\n');
  // BOM so Excel opens the peso sign / names as UTF-8.
  browser.downloadTextFile(fileName, '\uFEFF$csv', mimeType: 'text/csv');
}

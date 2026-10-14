import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/core/constants.dart';
import 'package:foodrush/models/order.dart';
import 'package:foodrush/shared/sales_report.dart';

Order _order(String id, String status, double total, DateTime at,
        {String payment = kPayCash, String stall = 'Kusina'}) =>
    Order.fromMap(id, {
      'vendorId': stall,
      'vendorName': stall,
      'subtotal': total,
      'total': total,
      'status': status,
      'paymentMethod': payment,
      'items': [
        {'productId': 'adobo', 'name': 'Adobo', 'unitPrice': total, 'qty': 1,
          'lineTotal': total},
      ],
    }).copyCreatedAt(at);

extension on Order {
  // createdAt comes from a Timestamp in Firestore; tests set it directly.
  Order copyCreatedAt(DateTime at) => Order(
        id: id,
        orderNumber: orderNumber,
        customerId: customerId,
        vendorId: vendorId,
        vendorName: vendorName,
        subtotal: subtotal,
        total: total,
        status: status,
        paymentMethod: paymentMethod,
        items: items,
        createdAt: at,
      );
}

void main() {
  final start = DateTime(2026, 10, 8);

  test('revenue counts completed orders only', () {
    final r = SalesReport.from([
      _order('a', kOrderCompleted, 100, DateTime(2026, 10, 8, 12)),
      _order('b', kOrderCompleted, 50, DateTime(2026, 10, 9, 9),
          payment: kPayGcash),
      _order('c', kOrderPreparing, 999, DateTime(2026, 10, 9, 10)),
      _order('d', kOrderCancelled, 70, DateTime(2026, 10, 9, 11)),
      _order('e', kOrderRejected, 30, DateTime(2026, 10, 10, 11)),
    ], start, 7);

    expect(r.revenue, 150);
    expect(r.completed, 2);
    expect(r.lost, 2);
    expect(r.cashRevenue, 100);
    expect(r.gcashRevenue, 50);
  });

  test('buckets by day and by hour', () {
    final r = SalesReport.from([
      _order('a', kOrderCompleted, 100, DateTime(2026, 10, 8, 12, 30)),
      _order('b', kOrderCompleted, 40, DateTime(2026, 10, 8, 12, 45)),
      _order('c', kOrderCompleted, 60, DateTime(2026, 10, 14, 8)),
    ], start, 7);

    expect(r.daily, hasLength(7));
    expect(r.daily.first.revenue, 140);
    expect(r.daily.first.orders, 2);
    expect(r.daily.last.revenue, 60);
    expect(r.byHour[12], 2);
    expect(r.byHour[8], 1);
  });

  test('ranks best sellers and stalls', () {
    final r = SalesReport.from([
      _order('a', kOrderCompleted, 100, DateTime(2026, 10, 8, 12), stall: 'A'),
      _order('b', kOrderCompleted, 300, DateTime(2026, 10, 8, 13), stall: 'B'),
    ], start, 7);

    expect(r.byStall.map((e) => e.key), ['B', 'A']);
    expect(r.topItems.single.qty, 2);
  });
}

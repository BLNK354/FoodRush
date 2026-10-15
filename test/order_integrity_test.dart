import 'package:flutter_test/flutter_test.dart';
import 'package:foodrush/core/constants.dart';
import 'package:foodrush/models/order.dart';

/// The stall-side check that an order's money adds up and matches the menu.
void main() {
  group('integrityIssues', () {
    Order tampered({double unit = 50, double total = 100}) => Order.fromMap('x', {
          'vendorId': 'v1',
          'customerId': 'student1',
          'subtotal': 100,
          'discount': 0,
          'total': total,
          'status': kOrderAccepted,
          'paymentMethod': kPayCash,
          'items': [
            {'productId': 'adobo', 'name': 'Adobo', 'unitPrice': unit, 'qty': 2,
              'lineTotal': unit * 2},
          ],
        });

    test('a clean order has no issues', () {
      expect(tampered().integrityIssues({'adobo': 50}), isEmpty);
    });

    test('flags prices that differ from the menu', () {
      final issues = tampered(unit: 1, total: 100).integrityIssues({'adobo': 50});
      expect(issues.join(' '), contains('menu says 50.00'));
    });

    test('flags totals that do not add up', () {
      expect(tampered(total: 1).integrityIssues(), contains("Total doesn't add up"));
    });

    test('flags stock taken that does not match the items', () {
      final o = Order.fromMap('y', {
        'subtotal': 50, 'discount': 0, 'total': 50, 'status': kOrderAccepted,
        'paymentMethod': kPayCash, 'stockTaken': {'adobo': 20},
        'items': [
          {'productId': 'adobo', 'name': 'Adobo', 'unitPrice': 50, 'qty': 1, 'lineTotal': 50},
        ],
      });
      expect(o.integrityIssues().join(), contains('Took 20 from stock but ordered 1'));
    });

    test('flags items missing from the menu', () {
      expect(tampered().integrityIssues({}).join(), contains('not on your menu'));
    });
  });
}

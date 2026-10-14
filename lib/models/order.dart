import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ---------------------------------------------------------------------------
// Line item — embedded in the order doc.
// ---------------------------------------------------------------------------
class OrderItem {
  final String productId;
  final String name;
  final double unitPrice;
  final int qty;
  final double lineTotal;

  /// True when placing the order took this qty out of the product's stock
  /// (stock-limited product), so cancelling must put it back.
  final bool stockTracked;

  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
    this.stockTracked = false,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: (m['productId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        unitPrice: ((m['unitPrice'] ?? 0) as num).toDouble(),
        qty: ((m['qty'] ?? 0) as num).toInt(),
        lineTotal: ((m['lineTotal'] ?? 0) as num).toDouble(),
        stockTracked: m['stockTracked'] == true,
      );
}

// ---------------------------------------------------------------------------
// Order (Firestore: orders/{autoId})
// One document per order with embedded items — single reads, cheap streams.
// ---------------------------------------------------------------------------
class Order {
  final String id;
  final String orderNumber;
  final String customerId;
  final String vendorId;
  final double subtotal;
  final double discount;
  final double total;
  final String status; // see kOrder* constants
  final String paymentMethod; // gcash | cash
  final String paymentStatus; // unpaid | pending_verification | paid
  final String? promoCode;
  final String? note;
  final int? queueNumber;
  final String? rejectReason;

  /// GCash receipt — one upload per order (re-upload overwrites).
  final String? receiptUrl;
  final String? receiptStatus; // pending | verified | rejected
  final String? receiptNote;

  final String? vendorName; // denormalized for display
  final String? customerName; // denormalized for display
  final DateTime? createdAt;
  final DateTime? readyAt;
  final DateTime? completedAt;

  /// Requested pickup time; null = ASAP.
  final DateTime? pickupAt;

  /// Set once cancelled/rejected stock has been returned (never twice).
  final bool stockReleased;

  /// GCash money to send back: null (none) | owed | refunded.
  final String? refundStatus;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.vendorId,
    required this.subtotal,
    this.discount = 0,
    required this.total,
    required this.status,
    required this.paymentMethod,
    this.paymentStatus = 'unpaid',
    this.promoCode,
    this.note,
    this.queueNumber,
    this.rejectReason,
    this.receiptUrl,
    this.receiptStatus,
    this.receiptNote,
    this.vendorName,
    this.customerName,
    this.createdAt,
    this.readyAt,
    this.completedAt,
    this.pickupAt,
    this.stockReleased = false,
    this.refundStatus,
    this.items = const [],
  });

  bool get isPaidFlow => paymentMethod == 'gcash';

  bool get refundOwed => refundStatus == 'owed';

  /// Reasons this order's money doesn't add up. Rules can check that the
  /// totals are consistent but not that each line matches the menu, so the
  /// stall re-checks here. [menuPrices] = productId -> current price; a
  /// missing product is only reported when the map is given.
  List<String> integrityIssues([Map<String, double>? menuPrices]) {
    bool off(double a, double b) => (a - b).abs() >= 0.01;
    final issues = <String>[];
    var sum = 0.0;
    for (final it in items) {
      sum += it.lineTotal;
      if (it.qty <= 0) issues.add('${it.name}: quantity ${it.qty}');
      if (off(it.unitPrice * it.qty, it.lineTotal)) {
        issues.add("${it.name}: line total doesn't match its price");
      }
      final menu = menuPrices?[it.productId];
      if (menuPrices != null && menu == null) {
        issues.add('${it.name}: not on your menu');
      } else if (menu != null && off(menu, it.unitPrice)) {
        issues.add('${it.name}: charged ${it.unitPrice.toStringAsFixed(2)}, '
            'menu says ${menu.toStringAsFixed(2)}');
      }
    }
    if (off(sum, subtotal)) issues.add("Items don't add up to the subtotal");
    if (discount < 0 || discount > subtotal) issues.add('Invalid discount');
    if (discount > 0 && (promoCode == null || promoCode!.isEmpty)) {
      issues.add('Discount without a promo code');
    }
    if (off(total, subtotal - discount)) issues.add("Total doesn't add up");
    return issues;
  }
  bool get isActive =>
      status != 'completed' && status != 'rejected' && status != 'cancelled';

  factory Order.fromMap(String id, Map<String, dynamic> m) => Order(
        id: id,
        orderNumber: (m['orderNumber'] ?? '') as String,
        customerId: (m['customerId'] ?? '') as String,
        vendorId: (m['vendorId'] ?? '') as String,
        subtotal: ((m['subtotal'] ?? 0) as num).toDouble(),
        discount: ((m['discount'] ?? 0) as num).toDouble(),
        total: ((m['total'] ?? 0) as num).toDouble(),
        status: (m['status'] ?? 'awaiting_payment') as String,
        paymentMethod: (m['paymentMethod'] ?? 'cash') as String,
        paymentStatus: (m['paymentStatus'] ?? 'unpaid') as String,
        promoCode: m['promoCode'] as String?,
        note: m['note'] as String?,
        queueNumber: (m['queueNumber'] as num?)?.toInt(),
        rejectReason: m['rejectReason'] as String?,
        receiptUrl: m['receiptUrl'] as String?,
        receiptStatus: m['receiptStatus'] as String?,
        receiptNote: m['receiptNote'] as String?,
        vendorName: m['vendorName'] as String?,
        customerName: m['customerName'] as String?,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        readyAt: (m['readyAt'] as Timestamp?)?.toDate(),
        completedAt: (m['completedAt'] as Timestamp?)?.toDate(),
        pickupAt: (m['pickupAt'] as Timestamp?)?.toDate(),
        stockReleased: m['stockReleased'] == true,
        refundStatus: m['refundStatus'] as String?,
        items: ((m['items'] as List<dynamic>? ?? const []))
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

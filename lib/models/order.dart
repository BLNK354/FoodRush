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

  const OrderItem({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
  });

  factory OrderItem.fromMap(Map<String, dynamic> m) => OrderItem(
        productId: (m['productId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        unitPrice: ((m['unitPrice'] ?? 0) as num).toDouble(),
        qty: ((m['qty'] ?? 0) as num).toInt(),
        lineTotal: ((m['lineTotal'] ?? 0) as num).toDouble(),
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
    this.items = const [],
  });

  bool get isPaidFlow => paymentMethod == 'gcash';
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
        items: ((m['items'] as List<dynamic>? ?? const []))
            .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

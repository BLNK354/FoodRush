import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

import '../core/constants.dart';
import '../models/misc.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/user.dart';

/// Data-access layer over Firestore.
/// All methods throw FirebaseException on failure; callers catch and show.
class Repository {
  Repository._();
  static final instance = Repository._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  String get _uid => _auth.currentUser!.uid;

  // =========================================================================
  // IMAGES (stored inline in Firestore as data URLs — no Cloud Storage,
  // which requires the paid Blaze plan. Images are compressed to keep the
  // 1MB-per-document Firestore limit comfortable.)
  // =========================================================================

  /// Compresses [bytes] to a JPEG data URL (max dimension [maxDim],
  /// quality [quality]) suitable for storing directly in a Firestore doc.
  Future<String> uploadImage({
    required String pathPrefix, // kept for API compatibility; unused
    required Uint8List bytes,
    required String fileName,
    int maxDim = 720,
    int quality = 72,
  }) async {
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Unsupported image file.');
    }
    if (decoded.width > maxDim || decoded.height > maxDim) {
      decoded = img.copyResize(
        decoded,
        width: decoded.width >= decoded.height ? maxDim : null,
        height: decoded.height > decoded.width ? maxDim : null,
        interpolation: img.Interpolation.average,
      );
    }
    final jpeg = img.encodeJpg(decoded, quality: quality);
    final b64 = base64Encode(jpeg);
    return 'data:image/jpeg;base64,$b64';
  }

  // =========================================================================
  // USERS (admin)
  // =========================================================================

  Future<List<Profile>> listProfiles({String? role}) async {
    Query<Map<String, dynamic>> q = _db.collection(kColUsers);
    if (role != null) q = q.where('role', isEqualTo: role);
    final snap = await q.get();
    final list =
        snap.docs.map((d) => Profile.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  Future<void> setUserActive(String userId, bool active) async {
    await _db.collection(kColUsers).doc(userId).update({'isActive': active});
  }

  // =========================================================================
  // VENDORS
  // =========================================================================

  /// Verified stalls for customers (optionally open-only).
  Future<List<Vendor>> listApprovedVendors({bool openOnly = false}) async {
    Query<Map<String, dynamic>> q =
        _db.collection(kColVendors).where('isVerified', isEqualTo: true);
    if (openOnly) q = q.where('isOpen', isEqualTo: true);
    final snap = await q.get();
    final list =
        snap.docs.map((d) => Vendor.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Vendor?> getVendor(String id) async {
    final snap = await _db.collection(kColVendors).doc(id).get();
    if (!snap.exists) return null;
    return Vendor.fromMap(snap.id, snap.data()!);
  }

  Future<Vendor?> getMyVendor() async {
    final snap = await _db
        .collection(kColVendors)
        .where('ownerId', isEqualTo: _uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Vendor.fromMap(d.id, d.data());
  }

  Future<void> updateMyVendor({
    required String vendorId,
    required String name,
    String? description,
    String? gcashNumber,
    String? gcashName,
    String? pickupPoint,
    bool? isOpen,
  }) async {
    await _db.collection(kColVendors).doc(vendorId).update({
      'name': name,
      'description': description,
      'gcashNumber': gcashNumber,
      'gcashName': gcashName,
      'pickupPoint': pickupPoint,
      if (isOpen != null) 'isOpen': isOpen,
    });
  }

  /// Admin: every stall with owner info joined in code.
  Future<List<VendorWithOwner>> listAllVendors() async {
    final snap =
        await _db.collection(kColVendors).orderBy('createdAt', descending: true).get();
    final owners = <String, Map<String, dynamic>?>{};
    final out = <VendorWithOwner>[];
    for (final d in snap.docs) {
      final ownerId = d.data()['ownerId'] as String?;
      Map<String, dynamic>? owner;
      if (ownerId != null) {
        owner = owners[ownerId] ??= await _readUser(ownerId);
      }
      out.add(VendorWithOwner.fromMaps(d.id, d.data(), owner));
    }
    return out;
  }

  Future<Map<String, dynamic>?> _readUser(String uid) async {
    final snap = await _db.collection(kColUsers).doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  // Admin operations.
  Future<void> setVendorVerified(String vendorId, bool verified) async {
    await _db
        .collection(kColVendors)
        .doc(vendorId)
        .update({'isVerified': verified});
  }

  Future<void> deleteVendor(String vendorId) async {
    final batch = _db.batch();
    final vendorRef = _db.collection(kColVendors).doc(vendorId);
    // Subcollections (products, categories) are deleted by rules/consolation;
    // docs removal here covers the vendor doc itself.
    batch.delete(vendorRef);
    await batch.commit();
  }

  // =========================================================================
  // PRODUCTS + CATEGORIES (subcollections of vendors/{vendorId})
  // =========================================================================

  Future<List<Product>> listProducts(String vendorId) async {
    final snap = await _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColProducts)
        .get();
    final list =
        snap.docs.map((d) => Product.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<void> upsertProduct({
    String? id,
    required String vendorId,
    required String name,
    String? description,
    required double price,
    String? imageUrl,
    required bool isAvailable,
    int? stockQty,
    String? categoryId,
  }) async {
    final ref = _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColProducts);
    final data = {
      'vendorId': vendorId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'stockQty': stockQty,
      'categoryId': categoryId,
    };
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.add(data);
    } else {
      await ref.doc(id).update(data);
    }
  }

  Future<void> deleteProduct(String vendorId, String id) async {
    await _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColProducts)
        .doc(id)
        .delete();
  }

  Future<List<ProductCategory>> listCategories(String vendorId) async {
    final snap = await _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColCategories)
        .get();
    final list = snap.docs
        .map((d) => ProductCategory.fromMap(d.id, d.data()))
        .toList();
    list.sort((a, b) => a.sort.compareTo(b.sort));
    return list;
  }

  Future<void> addCategory({
    required String vendorId,
    required String name,
    int sort = 0,
  }) async {
    await _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColCategories)
        .add({'vendorId': vendorId, 'name': name, 'sort': sort});
  }

  Future<void> deleteCategory(
      String vendorId, String categoryId) async {
    await _db
        .collection(kColVendors)
        .doc(vendorId)
        .collection(kColCategories)
        .doc(categoryId)
        .delete();
  }

  // =========================================================================
  // PROMOTIONS
  // =========================================================================

  /// Stall-owned promos + platform-wide ones (merged client-side so no
  /// composite index is required).
  Future<List<Promotion>> listPromotions({String? vendorId}) async {
    if (vendorId == null) return listPromotionsAdmin();
    final results = await Future.wait([
      _db
          .collection(kColPromotions)
          .where('vendorId', isEqualTo: vendorId)
          .get(),
      _db
          .collection(kColPromotions)
          .where('vendorId', isEqualTo: null)
          .get(),
    ]);
    final list = [
      for (final s in results)
        ...s.docs.map((d) => Promotion.fromMap(d.id, d.data())),
    ];
    list.sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  Future<List<Promotion>> listPromotionsAdmin() async {
    final snap = await _db.collection(kColPromotions).get();
    final list =
        snap.docs.map((d) => Promotion.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => a.code.compareTo(b.code));
    return list;
  }

  Future<void> upsertPromotion({
    String? id,
    String? vendorId,
    required String code,
    required String discountType,
    required double discountValue,
    double? minOrder,
    required bool isActive,
    DateTime? startsAt,
    DateTime? endsAt,
  }) async {
    final data = {
      'vendorId': vendorId,
      'code': code.trim().toUpperCase(),
      'discountType': discountType,
      'discountValue': discountValue,
      'minOrder': minOrder,
      'isActive': isActive,
      'startsAt': startsAt == null ? null : Timestamp.fromDate(startsAt),
      'endsAt': endsAt == null ? null : Timestamp.fromDate(endsAt),
    };
    if (id == null) {
      await _db.collection(kColPromotions).add(data);
    } else {
      await _db.collection(kColPromotions).doc(id).update(data);
    }
  }

  Future<void> deletePromotion(String id) async {
    await _db.collection(kColPromotions).doc(id).delete();
  }

  /// In-app promo validation (replaces the SQL RPC).
  Future<PromoResult> applyPromo({
    required String code,
    required String vendorId,
    required double subtotal,
  }) async {
    final clean = code.trim().toUpperCase();
    final snap = await _db
        .collection(kColPromotions)
        .where('code', isEqualTo: clean)
        .limit(5)
        .get();
    Promotion? match;
    for (final d in snap.docs) {
      final p = Promotion.fromMap(d.id, d.data());
      if (!p.isActive) continue;
      if (p.vendorId != null && p.vendorId != vendorId) continue;
      final now = DateTime.now();
      if (p.startsAt != null && p.startsAt!.isAfter(now)) continue;
      if (p.endsAt != null && p.endsAt!.isBefore(now)) continue;
      match = p;
      break;
    }
    if (match == null) {
      return const PromoResult(
          valid: false, discount: 0, message: 'Promo code not found or expired.');
    }
    if (match.minOrder != null && subtotal < match.minOrder!) {
      return PromoResult(
        valid: false,
        discount: 0,
        message: 'Minimum order of ₱${match.minOrder!.toStringAsFixed(0)} required.',
      );
    }
    final discount = match.discountType == 'percent'
        ? double.parse((subtotal * match.discountValue / 100).toStringAsFixed(2))
        : (match.discountValue > subtotal ? subtotal : match.discountValue);
    return PromoResult(valid: true, discount: discount, message: 'Promo applied!');
  }

  // =========================================================================
  // ORDERS
  // =========================================================================

  String _orderNumber() {
    final now = DateTime.now();
    final ymd =
        '${now.year.toString().substring(2)}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'FR-$ymd-${now.microsecondsSinceEpoch % 10000}';
  }

  /// Places an order atomically: validates products, decrements stock,
  /// assigns the per-vendor daily queue number.
  Future<Map<String, String>> placeOrder({
    required String vendorId,
    required List<Map<String, dynamic>> items,
    required String paymentMethod,
    String? promoCode,
    String? note,
  }) async {
    final orderId = _db.collection(kColOrders).doc().id;
    final vendorDoc = await _db.collection(kColVendors).doc(vendorId).get();
    if (!vendorDoc.exists) throw Exception('Stall not found');
    final vendorData = vendorDoc.data()!;
    if (vendorData['isOpen'] != true) {
      throw Exception('This stall is currently closed.');
    }

    // midnight today
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayStartTs = Timestamp.fromDate(dayStart);

    double subtotal = 0;
    double discount = 0;
    int queue = 0;

    await _db.runTransaction((tx) async {
      final countersRef =
          _db.collection(kColCounters).doc('vendor_$vendorId');
      final counterSnap = await tx.get(countersRef);
      int lastCount = 0;
      DateTime? counterDay;
      if (counterSnap.exists) {
        lastCount = ((counterSnap.data()!['count'] ?? 0) as num).toInt();
        counterDay = (counterSnap.data()!['day'] as Timestamp?)?.toDate();
      }
      final sameDay = counterDay != null &&
          counterDay.year == dayStart.year &&
          counterDay.month == dayStart.month &&
          counterDay.day == dayStart.day;
      final count = sameDay ? lastCount : 0;
      queue = count + 1;

      // Validate + price each item.
      final pricedItems = <Map<String, dynamic>>[];
      var sum = 0.0;
      for (final it in items) {
        final productId = it['product_id'] as String;
        final qty = (it['qty'] as num).toInt();
        final prodRef = _db
            .collection(kColVendors)
            .doc(vendorId)
            .collection(kColProducts)
            .doc(productId);
        final prodSnap = await tx.get(prodRef);
        if (!prodSnap.exists) {
          throw Exception('A product in your cart no longer exists.');
        }
        final p = Product.fromMap(prodSnap.id, prodSnap.data()!);
        if (!p.isAvailable) {
          throw Exception('"${p.name}" is currently unavailable.');
        }
        if (p.stockQty != null && p.stockQty! < qty) {
          throw Exception('"${p.name}" only has ${p.stockQty} left.');
        }
        tx.update(prodRef, {'stockQty': (p.stockQty ?? 0) - qty});
        pricedItems.add({
          'productId': p.id,
          'name': p.name,
          'unitPrice': p.price,
          'qty': qty,
          'lineTotal': double.parse((p.price * qty).toStringAsFixed(2)),
        });
        sum += p.price * qty;
      }
      subtotal = double.parse(sum.toStringAsFixed(2));

      discount = 0; // re-validated below if a code was provided
      if (promoCode != null && promoCode.trim().isNotEmpty) {
        final promo =
            await applyPromo(code: promoCode, vendorId: vendorId, subtotal: subtotal);
        if (promo.valid) discount = promo.discount;
      }

      tx.set(countersRef, {
        'count': queue,
        'day': dayStartTs,
      }, SetOptions(merge: true));

      tx.set(_db.collection(kColOrders).doc(orderId), {
        'orderNumber': _orderNumber(),
        'customerId': _uid,
        'customerName': _auth.currentUser?.displayName ?? '',
        'vendorId': vendorId,
        'vendorName': vendorData['name'] ?? '',
        'subtotal': subtotal,
        'discount': discount,
        'total': double.parse((subtotal - discount).toStringAsFixed(2)),
        'status': paymentMethod == kPayGcash
            ? kOrderAwaitingPayment
            : kOrderAccepted,
        'paymentMethod': paymentMethod,
        'paymentStatus': paymentMethod == kPayGcash ? 'unpaid' : 'paid',
        'promoCode': (promoCode != null && promoCode.trim().isNotEmpty)
            ? promoCode.trim().toUpperCase()
            : null,
        'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
        'queueNumber': queue,
        'receiptUrl': null,
        'receiptStatus': null,
        'receiptNote': null,
        'createdAt': FieldValue.serverTimestamp(),
        'items': pricedItems,
      });
    });

    return {'orderId': orderId, 'queueNumber': '$queue'};
  }

  /// Orders for the signed-in customer, newest first — live stream.
  /// (Sorted client-side to avoid needing a composite index.)
  Stream<List<Order>> streamMyOrders() {
    return _db
        .collection(kColOrders)
        .where('customerId', isEqualTo: _uid)
        .limit(200)
        .snapshots()
        .map(_newestFirst);
  }

  /// Orders for one vendor — live stream.
  Stream<List<Order>> streamVendorOrders(String vendorId) {
    return _db
        .collection(kColOrders)
        .where('vendorId', isEqualTo: vendorId)
        .limit(300)
        .snapshots()
        .map(_newestFirst);
  }

  static List<Order> _newestFirst(QuerySnapshot<Map<String, dynamic>> s) {
    final list =
        s.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list;
  }

  /// All orders (admin) — live stream.
  Stream<List<Order>> streamAllOrders() {
    return _db
        .collection(kColOrders)
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((s) => s.docs.map((d) => Order.fromMap(d.id, d.data())).toList());
  }

  Future<Order> getOrder(String id) async {
    final snap = await _db.collection(kColOrders).doc(id).get();
    if (!snap.exists) throw Exception('Order not found');
    return Order.fromMap(snap.id, snap.data()!);
  }

  /// Live stream for the tracking page.
  Stream<Order?> streamOrder(String id) {
    return _db.collection(kColOrders).doc(id).snapshots().map(
        (s) => s.exists ? Order.fromMap(s.id, s.data()!) : null);
  }

  /// Customer uploads a GCash receipt (moves order to proof_submitted).
  Future<void> submitProof({
    required String orderId,
    required String imageUrl,
  }) async {
    await _db.collection(kColOrders).doc(orderId).update({
      'receiptUrl': imageUrl,
      'receiptStatus': kProofPending,
      'status': kOrderProofSubmitted,
      'paymentStatus': 'pending_verification',
    });
  }

  /// Vendor/admin verify or reject a GCash proof (or accept a cash order).
  Future<void> reviewPayment({
    required String orderId,
    required bool approve,
    String? note,
  }) async {
    await _db.collection(kColOrders).doc(orderId).update({
      'status': approve ? kOrderAccepted : kOrderRejected,
      'paymentStatus': approve ? 'paid' : 'unpaid',
      'receiptStatus': approve ? kProofVerified : kProofRejected,
      'receiptNote': note,
      if (!approve) 'rejectReason': note,
    });
  }

  Future<void> updateOrderStatus(String orderId, String status) async {
    final patch = <String, dynamic>{'status': status};
    if (status == kOrderReady) {
      patch['readyAt'] = FieldValue.serverTimestamp();
    }
    if (status == kOrderCompleted) {
      patch['completedAt'] = FieldValue.serverTimestamp();
    }
    await _db.collection(kColOrders).doc(orderId).update(patch);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _db.collection(kColOrders).doc(orderId).update({
      'status': kOrderCancelled,
      if (reason != null) 'rejectReason': reason,
    });
  }

  // =========================================================================
  // FAVORITES (Firestore: favorites/{uid_vendorId})
  // =========================================================================

  Future<Set<String>> listMyFavoriteVendorIds() async {
    final snap = await _db
        .collection(kColFavorites)
        .where('customerId', isEqualTo: _uid)
        .get();
    return snap.docs
        .map((d) => d.data()['vendorId'] as String)
        .toSet();
  }

  Future<void> toggleFavorite(String vendorId, bool favorite) async {
    final ref =
        _db.collection(kColFavorites).doc('${_uid}_$vendorId');
    if (favorite) {
      await ref.set({
        'customerId': _uid,
        'vendorId': vendorId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.delete();
    }
  }

  // =========================================================================
  // STATS
  // =========================================================================

  Future<Map<String, dynamic>> vendorStats(String vendorId) async {
    // Equality-only query (auto-indexed); "today" is filtered client-side.
    final snap = await _db
        .collection(kColOrders)
        .where('vendorId', isEqualTo: vendorId)
        .get();

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    var ordersToday = 0;
    var active = 0;
    var revenue = 0.0;
    for (final d in snap.docs) {
      final o = Order.fromMap(d.id, d.data());
      final created = o.createdAt;
      if (created == null || created.isBefore(dayStart)) continue;
      ordersToday++;
      if (o.isActive) active++;
      if (o.status == kOrderCompleted) revenue += o.total;
    }
    return {
      'ordersToday': ordersToday,
      'active': active,
      'revenueToday': revenue,
    };
  }

  Future<Map<String, dynamic>> adminStats() async {
    final now = DateTime.now();
    final dayStart = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    final usersSnap = await _db.collection(kColUsers).get();
    final vendorsSnap = await _db.collection(kColVendors).get();
    final ordersSnap = await _db
        .collection(kColOrders)
        .where('createdAt', isGreaterThanOrEqualTo: dayStart)
        .get();

    var pendingVendors = 0;
    for (final d in vendorsSnap.docs) {
      if (d.data()['isVerified'] != true) pendingVendors++;
    }
    var gmvToday = 0.0;
    for (final d in ordersSnap.docs) {
      gmvToday += ((d.data()['total'] ?? 0) as num).toDouble();
    }
    return {
      'customers': usersSnap.docs
          .where((d) => d.data()['role'] == kRoleCustomer)
          .length,
      'vendors': vendorsSnap.docs.length,
      'pendingVendors': pendingVendors,
      'ordersToday': ordersSnap.docs.length,
      'gmvToday': gmvToday,
    };
  }

  // =========================================================================
  // PLATFORM SETTINGS
  // =========================================================================

  Future<Map<String, dynamic>?> getPlatformGcash() async {
    final snap = await _db
        .collection(kColSettings)
        .doc(kSettingsDocPlatformGcash)
        .get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> setPlatformGcash({
    required String number,
    required String name,
  }) async {
    await _db.collection(kColSettings).doc(kSettingsDocPlatformGcash).set({
      'number': number,
      'name': name,
    });
  }

  /// Closes the one-time admin-claim window (idempotent; fails silently if
  /// another admin already claimed it).
  Future<void> markBootstrapped() async {
    try {
      await _db.collection(kColSettings).doc('app_bootstrapped').set({
        'bootstrappedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Already claimed or offline — non-fatal.
    }
  }
}

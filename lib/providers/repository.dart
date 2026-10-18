import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image/image.dart' as img;

import '../core/constants.dart';
import '../models/branding.dart';
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
  // PROFILE PHOTOS (avatars/{uid}) — optional; seen by the person, the
  // stalls they order from (owners/staff) and admins. Never by students.
  // =========================================================================

  /// Centre-crops [bytes] to a small square JPEG data URL for an avatar.
  Future<String> makeAvatar(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Unsupported image file.');
    final square = img.copyResizeCropSquare(decoded,
        size: 320, interpolation: img.Interpolation.average);
    for (final q in [82, 70, 58]) {
      final url =
          'data:image/jpeg;base64,${base64Encode(img.encodeJpg(square, quality: q))}';
      if (url.length <= 95000) return url;
    }
    throw Exception('That photo is too detailed. Try another one.');
  }

  Future<void> setMyAvatar(String? dataUrl) {
    final ref = _db.collection(kColAvatars).doc(_uid);
    return dataUrl == null
        ? ref.delete()
        : ref.set({'photo': dataUrl, 'updatedAt': FieldValue.serverTimestamp()});
  }

  /// Admin moderation: removes someone's photo.
  Future<void> removeAvatar(String uid) =>
      _db.collection(kColAvatars).doc(uid).delete();

  final Map<String, Stream<String?>> _avatarStreams = {};
  final Map<String, String?> _avatarLatest = {};

  /// A user's photo (null = none), shared between every widget showing it.
  /// One Firestore listener per user; a widget that subscribes later gets
  /// the latest photo immediately (a plain broadcast stream would only
  /// give it future changes).
  Stream<String?> streamAvatar(String uid) async* {
    if (_avatarLatest.containsKey(uid)) yield _avatarLatest[uid];
    yield* _avatarStreams.putIfAbsent(
        uid,
        () => _db
            .collection(kColAvatars)
            .doc(uid)
            .snapshots()
            .map((s) => _avatarLatest[uid] = s.data()?['photo'] as String?)
            .handleError((Object _) {})
            .asBroadcastStream());
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

  /// Admin edit of any user. When [stallName] is given and the user owns no
  /// stall yet (e.g. just turned into a stall owner), an unverified stall is
  /// created for them — verify it under Stalls.
  Future<void> adminUpdateUser(
    String userId, {
    required String fullName,
    String? phone,
    String? studentNumber,
    required String role,
    required bool isActive,
    String? stallName,
  }) async {
    String? orNull(String? v) =>
        v == null || v.trim().isEmpty ? null : v.trim();
    await _db.collection(kColUsers).doc(userId).update({
      'fullName': fullName.trim(),
      'phone': orNull(phone),
      'studentNumber': orNull(studentNumber),
      'role': role,
      'isActive': isActive,
    });
    final name = orNull(stallName);
    if (role == kRoleVendor && name != null && !await userOwnsStall(userId)) {
      await _db.collection(kColVendors).add({
        'ownerId': userId,
        'name': name,
        'isVerified': false,
        'isOpen': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> userOwnsStall(String userId) async {
    final snap = await _db
        .collection(kColVendors)
        .where('ownerId', isEqualTo: userId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
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

  /// The stall I own, or (staff) the stall whose owner listed my email.
  Future<Vendor?> getMyVendor() async {
    var snap = await _db
        .collection(kColVendors)
        .where('ownerId', isEqualTo: _uid)
        .limit(1)
        .get();
    final email = _auth.currentUser?.email?.toLowerCase();
    if (snap.docs.isEmpty && email != null) {
      snap = await _db
          .collection(kColVendors)
          .where('staffEmails', arrayContains: email)
          .limit(1)
          .get();
    }
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Vendor.fromMap(d.id, d.data());
  }

  // =========================================================================
  // LOYALTY (loyalty/{vendorId}_{customerId}; written only by the stall)
  // =========================================================================

  DocumentReference<Map<String, dynamic>> _card(String vendorId, String customerId) =>
      _db.collection(kColLoyalty).doc('${vendorId}_$customerId');

  /// My stamp card at [vendorId] (student), or a card for [customerId]
  /// (stall). Null if they have no stamps there yet.
  Future<LoyaltyCard?> getLoyaltyCard(String vendorId, {String? customerId}) async {
    final snap = await _card(vendorId, customerId ?? _uid).get();
    return snap.exists ? LoyaltyCard.fromMap(snap.data()!) : null;
  }

  /// Stall: marks the order picked up and, if the stall runs a stamp card,
  /// gives the student one stamp, in one batch.
  Future<void> completeOrder(Order order, {required bool giveStamp}) async {
    final batch = _db.batch();
    batch.update(_db.collection(kColOrders).doc(order.id), {
      'status': kOrderCompleted,
      'completedAt': FieldValue.serverTimestamp(),
    });
    if (giveStamp) {
      batch.set(_card(order.vendorId, order.customerId), {
        'vendorId': order.vendorId,
        'customerId': order.customerId,
        'stamps': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Stall: hands over the reward, spending [cost] stamps. Fails if the card
  /// no longer has enough (e.g. redeemed on another device a moment ago).
  Future<void> redeemLoyalty(String vendorId, String customerId, int cost) =>
      _db.runTransaction((tx) async {
        final ref = _card(vendorId, customerId);
        final snap = await tx.get(ref);
        final stamps = (snap.data()?['stamps'] as num?)?.toInt() ?? 0;
        if (stamps < cost) {
          throw Exception('Not enough stamps ($stamps of $cost).');
        }
        tx.update(ref, {
          'stamps': stamps - cost,
          'redeemed': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

  Future<void> updateMyVendor({
    required String vendorId,
    required String name,
    String? description,
    String? gcashNumber,
    String? gcashName,
    String? pickupPoint,
    bool? isOpen,
    String? logoUrl, // new logo (data URL); null keeps the current one
    bool removeLogo = false,
    Map<int, DayHours>? hours, // empty map = no schedule
    int? prepMinutes,
    bool? loyaltyEnabled,
    int? loyaltyStamps,
    String? loyaltyReward,
    List<String>? staffEmails,
  }) async {
    await _db.collection(kColVendors).doc(vendorId).update({
      'name': name,
      'description': description,
      'gcashNumber': gcashNumber,
      'gcashName': gcashName,
      'pickupPoint': pickupPoint,
      if (isOpen != null) 'isOpen': isOpen,
      if (logoUrl != null) 'logoUrl': logoUrl,
      if (removeLogo && logoUrl == null) 'logoUrl': FieldValue.delete(),
      if (hours != null)
        'hours': {for (final e in hours.entries) '${e.key}': e.value.toMap()},
      if (prepMinutes != null) 'prepMinutes': prepMinutes,
      if (loyaltyEnabled != null) 'loyaltyEnabled': loyaltyEnabled,
      if (loyaltyStamps != null) 'loyaltyStamps': loyaltyStamps,
      if (loyaltyReward != null) 'loyaltyReward': loyaltyReward,
      if (staffEmails != null)
        'staffEmails': [for (final e in staffEmails) e.trim().toLowerCase()],
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

  /// Deletes the stall AND its products/categories — Firestore never
  /// cascades, so leaving them would orphan the whole menu.
  Future<void> deleteVendor(String vendorId) async {
    final vendorRef = _db.collection(kColVendors).doc(vendorId);
    final refs = <DocumentReference>[];
    for (final sub in [kColProducts, kColCategories]) {
      final snap = await vendorRef.collection(sub).get();
      refs.addAll(snap.docs.map((d) => d.reference));
    }
    refs.add(vendorRef); // last, so a partial failure can be retried
    const chunk = 400; // batches cap at 500 writes
    for (var i = 0; i < refs.length; i += chunk) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(chunk)) {
        batch.delete(r);
      }
      await batch.commit();
    }
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
    List<Addon> addons = const [],
    List<String> tags = const [],
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
      'addons': [for (final a in addons) a.toMap()],
      'tags': tags,
    };
    if (id == null) {
      data['createdAt'] = FieldValue.serverTimestamp();
      await ref.add(data);
    } else {
      await ref.doc(id).update(data);
    }
  }

  /// Flips only isAvailable (so add-ons/tags/stock are never rewritten).
  Future<void> setProductAvailable(
          String vendorId, String productId, bool available) =>
      _db
          .collection(kColVendors)
          .doc(vendorId)
          .collection(kColProducts)
          .doc(productId)
          .update({'isAvailable': available});

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
    DateTime? pickupAt, // null = ASAP
  }) async {
    final orderId = _db.collection(kColOrders).doc().id;
    final vendorDoc = await _db.collection(kColVendors).doc(vendorId).get();
    if (!vendorDoc.exists) throw Exception('Stall not found');
    final vendorData = vendorDoc.data()!;
    final vendor = Vendor.fromMap(vendorDoc.id, vendorData);
    final now = DateTime.now();
    if (!vendor.isOpenAt(now)) {
      throw Exception('This stall is currently closed.');
    }
    if (pickupAt != null) {
      if (pickupAt.isBefore(now)) {
        throw Exception('Pick a pickup time later than now.');
      }
      if (!vendor.isOpenAt(pickupAt)) {
        throw Exception('The stall is closed at that pickup time.');
      }
    }

    // midnight today
    final dayStart = DateTime(now.year, now.month, now.day);
    final dayStartTs = Timestamp.fromDate(dayStart);

    double subtotal = 0;
    double discount = 0;
    int queue = 0;

    await _db.runTransaction((tx) async {
      // Firestore transactions must do ALL reads before ANY write — reading
      // product 2 after writing product 1 fails on multi-item carts.
      final countersRef =
          _db.collection(kColCounters).doc('vendor_$vendorId');
      final counterSnap = await tx.get(countersRef);
      // Anti-spam: the rules allow one order per student every 30 s (via
      // users/{me}.lastOrderAt); say so nicely instead of "permission denied".
      final userRef = _db.collection(kColUsers).doc(_uid);
      final lastOrderAt =
          ((await tx.get(userRef)).data()?['lastOrderAt'] as Timestamp?)?.toDate();
      if (lastOrderAt != null &&
          DateTime.now().difference(lastOrderAt) < kOrderCooldown) {
        throw Exception('You just placed an order. Please wait '
            '${kOrderCooldown.inSeconds} seconds before ordering again.');
      }

      // Each product is read once, even if several lines (add-on combos)
      // use it; stock is checked against the product's total.
      final products = <String, (DocumentReference<Map<String, dynamic>>, Product)>{};
      final lines = <(Product, int, List<String>)>[];
      final totalQty = <String, int>{};
      for (final it in items) {
        final productId = it['product_id'] as String;
        final qty = (it['qty'] as num).toInt();
        final addons = [for (final a in (it['addons'] as List? ?? const [])) '$a'];
        if (!products.containsKey(productId)) {
          final prodRef = _db
              .collection(kColVendors)
              .doc(vendorId)
              .collection(kColProducts)
              .doc(productId);
          final prodSnap = await tx.get(prodRef);
          if (!prodSnap.exists) {
            throw Exception('A product in your cart no longer exists.');
          }
          products[productId] =
              (prodRef, Product.fromMap(prodSnap.id, prodSnap.data()!));
        }
        final p = products[productId]!.$2;
        if (!p.isAvailable) {
          throw Exception('"${p.name}" is currently unavailable.');
        }
        totalQty[productId] = (totalQty[productId] ?? 0) + qty;
        if (p.stockQty != null && p.stockQty! < totalQty[productId]!) {
          throw Exception('"${p.name}" only has ${p.stockQty} left.');
        }
        lines.add((p, qty, addons));
      }

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
      queue = (sameDay ? lastCount : 0) + 1;

      final pricedItems = <Map<String, dynamic>>[];
      var sum = 0.0;
      for (final (p, qty, addons) in lines) {
        // Price from the menu as it is NOW (base + chosen add-ons).
        final unit = p.priceWith(addons);
        if (unit == null) {
          throw Exception('An add-on for "${p.name}" is no longer offered. '
              'Remove it from your cart and add it again.');
        }
        pricedItems.add({
          'productId': p.id,
          'name': p.name,
          'unitPrice': unit,
          'qty': qty,
          'lineTotal': double.parse((unit * qty).toStringAsFixed(2)),
          if (addons.isNotEmpty) 'addons': addons,
          // Unlimited products (stockQty null) are never touched.
          'stockTracked': p.stockQty != null,
        });
        sum += unit * qty;
      }
      subtotal = double.parse(sum.toStringAsFixed(2));

      discount = 0; // re-validated here if a code was provided
      if (promoCode != null && promoCode.trim().isNotEmpty) {
        final promo =
            await applyPromo(code: promoCode, vendorId: vendorId, subtotal: subtotal);
        if (promo.valid) discount = promo.discount;
      }

      // ---- writes ----
      // Each stock change names this order; the rules check it takes exactly
      // the order's quantity (so stock can't be vandalised on its own).
      final stockTaken = <String, int>{};
      for (final MapEntry(key: id, value: (ref, p)) in products.entries) {
        if (p.stockQty != null) {
          stockTaken[id] = totalQty[id]!;
          tx.update(ref, {
            'stockQty': p.stockQty! - totalQty[id]!,
            'lastStockOrder': orderId,
          });
        }
      }
      tx.update(userRef, {'lastOrderAt': FieldValue.serverTimestamp()});

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
        'pickupAt': pickupAt == null ? null : Timestamp.fromDate(pickupAt),
        'receiptUrl': null,
        'receiptStatus': null,
        'receiptNote': null,
        'createdAt': FieldValue.serverTimestamp(),
        'items': pricedItems,
        'stockTaken': stockTaken,
      });
    });

    return {'orderId': orderId, 'queueNumber': '$queue'};
  }

  /// Orders the stall is still working through — drives "ready in about N
  /// min". Students can't read other people's orders, so the stall's app
  /// publishes this count on its queue counter ([publishActiveCount]); null
  /// when it never has.
  Future<int?> ordersAhead(String vendorId) async {
    final snap =
        await _db.collection(kColCounters).doc('vendor_$vendorId').get();
    return (snap.data()?['active'] as num?)?.toInt();
  }

  /// Orders a stall counts as "in the queue" for wait estimates.
  static bool isInQueue(Order o) =>
      o.status == kOrderProofSubmitted ||
      o.status == kOrderAccepted ||
      o.status == kOrderPreparing;

  /// Called by the stall's app whenever its live queue changes.
  Future<void> publishActiveCount(String vendorId, int active) =>
      _db.collection(kColCounters).doc('vendor_$vendorId').set({
        'active': active,
        'activeAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  /// Older orders for "Load more": [field] == [value] (or every order when
  /// [field] is null, admin), created before [before], newest first.
  Future<List<Order>> olderOrders({
    String? field,
    String? value,
    required DateTime before,
    int limit = 50,
  }) async {
    Query<Map<String, dynamic>> q = _db.collection(kColOrders);
    if (field != null) q = q.where(field, isEqualTo: value);
    final snap = await q
        .orderBy('createdAt', descending: true)
        .startAfter([Timestamp.fromDate(before)])
        .limit(limit)
        .get();
    return snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
  }

  /// Admin: every order since [start] (single-field range, no index).
  Future<List<Order>> listOrdersSince(DateTime start) async {
    final snap = await _db
        .collection(kColOrders)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .get();
    return snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
  }

  /// One-time read of every order a stall has received (reports).
  Future<List<Order>> listVendorOrders(String vendorId) async {
    final snap = await _db
        .collection(kColOrders)
        .where('vendorId', isEqualTo: vendorId)
        .get();
    return snap.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
  }

  /// Orders for the signed-in customer, newest first — live stream.
  /// (Sorted client-side to avoid needing a composite index.)
  Stream<List<Order>> streamMyOrders() =>
      _newestOrders('customerId', _uid, limit: 200);

  /// Orders for one vendor — live stream.
  Stream<List<Order>> streamVendorOrders(String vendorId) =>
      _newestOrders('vendorId', vendorId, limit: 300);

  /// The newest [limit] orders where [field] == [value], live.
  ///
  /// A limit WITHOUT orderBy returns an arbitrary (doc-id ordered) subset, so
  /// past the limit brand-new orders could silently go missing. Ordering by
  /// createdAt needs the composite indexes in firebase/firestore.indexes.json;
  /// until they're deployed Firestore answers failed-precondition and this
  /// falls back to the old unordered query instead of breaking the page.
  Stream<List<Order>> _newestOrders(String field, String value,
      {required int limit}) async* {
    final base = _db.collection(kColOrders).where(field, isEqualTo: value);
    try {
      await for (final s in base
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()) {
        yield _newestFirst(s);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      yield* base.limit(limit).snapshots().map(_newestFirst);
    }
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
    final patch = {
      'status': approve ? kOrderAccepted : kOrderRejected,
      'paymentStatus': approve ? 'paid' : 'unpaid',
      'receiptStatus': approve ? kProofVerified : kProofRejected,
      'receiptNote': note,
      if (!approve) 'rejectReason': note,
    };
    if (approve) {
      await _db.collection(kColOrders).doc(orderId).update(patch);
    } else {
      await _endOrderReleasingStock(orderId, patch);
    }
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

  /// Cancels an order (student, or the stall with a [reason]). A GCash order
  /// cancelled after the student sent money is flagged refund-owed.
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _endOrderReleasingStock(orderId, {
      'status': kOrderCancelled,
      if (reason != null) 'rejectReason': reason,
    }, owesRefund: (o) =>
        o.isPaidFlow &&
        (o.status == kOrderProofSubmitted || o.paymentStatus == 'paid'));
  }

  Future<void> markRefunded(String orderId) =>
      _db.collection(kColOrders).doc(orderId).update({
        'refundStatus': 'refunded',
        'refundedAt': FieldValue.serverTimestamp(),
      });

  /// Applies [patch] (a cancel/reject) and puts stock-tracked quantities back
  /// on their products, atomically and at most once per order.
  Future<void> _endOrderReleasingStock(
    String orderId,
    Map<String, dynamic> patch, {
    bool Function(Order before)? owesRefund,
  }) async {
    final orderRef = _db.collection(kColOrders).doc(orderId);
    final snap = await orderRef.get();
    if (!snap.exists) throw Exception('Order not found');
    final order = Order.fromMap(snap.id, snap.data()!);
    final batch = _db.batch();
    if (!order.stockReleased) {
      // Orders from before `stockTaken` existed: the stall/admin can still
      // restock from the items, but the rules won't let a student, so a
      // student cancelling such an order leaves stock for the stall to fix.
      final taken = order.stockTaken.isNotEmpty
          ? order.stockTaken
          : order.customerId == _uid
              ? const <String, int>{}
              : {
                  for (final it in order.items.where((i) => i.stockTracked))
                    it.productId: it.qty,
                };
      for (final e in taken.entries) {
        batch.update(
          _db
              .collection(kColVendors)
              .doc(order.vendorId)
              .collection(kColProducts)
              .doc(e.key),
          {'stockQty': FieldValue.increment(e.value), 'lastStockOrder': orderId},
        );
      }
    }
    batch.update(orderRef, {
      ...patch,
      'stockReleased': true,
      if (owesRefund?.call(order) ?? false) 'refundStatus': 'owed',
    });
    await batch.commit();
  }

  // =========================================================================
  // REVIEWS (reviews/{orderId}: one per completed order)
  // =========================================================================

  Future<Review?> getReview(String orderId) async {
    final snap = await _db.collection(kColReviews).doc(orderId).get();
    return snap.exists ? Review.fromMap(snap.id, snap.data()!) : null;
  }

  /// Newest reviews for a stall (sorted client-side: no composite index).
  Future<List<Review>> listVendorReviews(String vendorId,
      {int limit = 20}) async {
    final snap = await _db
        .collection(kColReviews)
        .where('vendorId', isEqualTo: vendorId)
        .get();
    final list =
        snap.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
    list.sort((a, b) => (b.createdAt ?? DateTime(2000))
        .compareTo(a.createdAt ?? DateTime(2000)));
    return list.take(limit).toList();
  }

  Future<void> replyToReview(String reviewId, String reply) =>
      _db.collection(kColReviews).doc(reviewId).update({
        'reply': reply.trim().isEmpty ? null : reply.trim(),
        'repliedAt': FieldValue.serverTimestamp(),
      });

  /// Admin: removes a review and takes it back out of the stall's average.
  Future<void> deleteReview(Review r) async {
    final batch = _db.batch();
    batch.delete(_db.collection(kColReviews).doc(r.id));
    batch.update(_db.collection(kColVendors).doc(r.vendorId), {
      'ratingSum': FieldValue.increment(-r.rating),
      'ratingCount': FieldValue.increment(-1),
    });
    await batch.commit();
  }

  // =========================================================================
  // ANNOUNCEMENT (settings/announcement)
  // =========================================================================

  Stream<Announcement> streamAnnouncement() => _db
      .collection(kColSettings)
      .doc(kSettingsDocAnnouncement)
      .snapshots()
      .map((s) => Announcement.fromMap(s.data()));

  Future<void> setAnnouncement({
    required String message,
    required bool active,
    required String level,
  }) =>
      _db.collection(kColSettings).doc(kSettingsDocAnnouncement).set({
        'message': message.trim(),
        'active': active,
        'level': level,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // =========================================================================
  // CONTENT (settings/home + banners) — the admin's Shop page CMS
  // =========================================================================

  Stream<HomeContent> streamHomeContent() => _db
      .collection(kColSettings)
      .doc(kSettingsDocHome)
      .snapshots()
      .map((s) => HomeContent.fromMap(s.data()));

  Future<void> setHomeContent({
    required String heroTitle,
    required String heroSubtitle,
  }) =>
      _db.collection(kColSettings).doc(kSettingsDocHome).set({
        'heroTitle': heroTitle.trim(),
        'heroSubtitle': heroSubtitle.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// The app's look (colours, logo, images, style). World-readable so the
  /// signed-out login screen follows it too.
  Stream<Branding> streamBranding() => _db
      .collection(kColSettings)
      .doc(kSettingsDocBranding)
      .snapshots()
      .map((s) => Branding.fromMap(s.data()));

  Future<void> saveBranding(Branding b) => _db
      .collection(kColSettings)
      .doc(kSettingsDocBranding)
      .set({...b.toMap(), 'updatedAt': FieldValue.serverTimestamp()});

  /// Every banner (live and hidden), in display order.
  Stream<List<HomeBanner>> streamBanners() =>
      _db.collection(kColBanners).snapshots().map((s) {
        final list =
            s.docs.map((d) => HomeBanner.fromMap(d.id, d.data())).toList();
        list.sort((a, b) => a.order.compareTo(b.order));
        return list;
      });

  /// Creates the banner when it has no id yet, otherwise replaces it.
  Future<void> saveBanner(HomeBanner b) {
    final data = {...b.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    final col = _db.collection(kColBanners);
    return b.id.isEmpty ? col.add(data) : col.doc(b.id).set(data);
  }

  Future<void> deleteBanner(String id) =>
      _db.collection(kColBanners).doc(id).delete();

  /// Rewrites `order` so banners show in the sequence of [ids].
  Future<void> reorderBanners(List<String> ids) async {
    final batch = _db.batch();
    for (var i = 0; i < ids.length; i++) {
      batch.update(_db.collection(kColBanners).doc(ids[i]), {'order': i});
    }
    await batch.commit();
  }

  /// Account deletion (student): refuses while orders are still active;
  /// otherwise replaces their name on past orders/reviews with
  /// "Deleted user", deletes their favourites and profile. Returns a reason
  /// it can't proceed, or null when done (the caller deletes the login).
  Future<String?> anonymiseAndDeleteMyData() async {
    final uid = _uid;
    final orders = await _db
        .collection(kColOrders)
        .where('customerId', isEqualTo: uid)
        .get();
    final mine = orders.docs.map((d) => Order.fromMap(d.id, d.data())).toList();
    if (mine.any((o) => o.isActive)) {
      return 'You still have active orders. Pick them up or cancel them first.';
    }
    final reviews = await _db
        .collection(kColReviews)
        .where('customerId', isEqualTo: uid)
        .get();
    final favs = await _db
        .collection(kColFavorites)
        .where('customerId', isEqualTo: uid)
        .get();
    final writes = <void Function(WriteBatch)>[
      for (final o in mine)
        (b) => b.update(_db.collection(kColOrders).doc(o.id),
            {'customerName': kDeletedUserName}),
      for (final r in reviews.docs)
        (b) => b.update(r.reference, {'customerName': kDeletedUserName}),
      for (final f in favs.docs) (b) => b.delete(f.reference),
    ];
    const chunk = 400;
    for (var i = 0; i < writes.length; i += chunk) {
      final batch = _db.batch();
      for (final w in writes.skip(i).take(chunk)) {
        w(batch);
      }
      await batch.commit();
    }
    try {
      await _db.collection(kColAvatars).doc(uid).delete();
    } catch (_) {}
    await _db.collection(kColUsers).doc(uid).delete();
    return null;
  }

  /// Saves the review and bumps the stall's rating aggregates in one batch.
  Future<void> submitReview({
    required Order order,
    required int rating,
    String? comment,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection(kColReviews).doc(order.id), {
      'orderId': order.id,
      'customerId': _uid,
      'vendorId': order.vendorId,
      'rating': rating,
      'comment':
          (comment == null || comment.trim().isEmpty) ? null : comment.trim(),
      'customerName': _auth.currentUser?.displayName ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_db.collection(kColVendors).doc(order.vendorId), {
      'ratingSum': FieldValue.increment(rating),
      'ratingCount': FieldValue.increment(1),
      // The rules only accept a rating bump that names the review being
      // created in this same batch.
      'lastReviewId': order.id,
    });
    await batch.commit();
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

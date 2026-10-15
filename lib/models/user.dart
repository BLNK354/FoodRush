import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ---------------------------------------------------------------------------
// User profile (Firestore: users/{uid})
// ---------------------------------------------------------------------------
class Profile {
  final String id;
  final String email;
  final String role;
  final String fullName;
  final String? phone;
  final bool isActive;
  final String? studentNumber;
  final DateTime? createdAt;

  const Profile({
    required this.id,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone,
    this.isActive = true,
    this.studentNumber,
    this.createdAt,
  });

  bool get isCustomer => role == 'customer';
  bool get isVendor => role == 'vendor';
  bool get isAdmin => role == 'admin';

  factory Profile.fromMap(String id, Map<String, dynamic> m) => Profile(
        id: id,
        email: (m['email'] ?? '') as String,
        role: (m['role'] ?? 'customer') as String,
        fullName: (m['fullName'] ?? '') as String,
        phone: m['phone'] as String?,
        isActive: (m['isActive'] ?? true) == true,
        studentNumber: m['studentNumber'] as String?,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      );
}

// ---------------------------------------------------------------------------
// Opening hours. Firestore `hours`: {"1": {"open": "07:00", "close": "17:00"},
// ...} keyed by DateTime.weekday (1 = Monday). A missing day = closed that day;
// a missing/empty map = no schedule (the manual open switch alone decides).
// ---------------------------------------------------------------------------
class DayHours {
  final int openMinute; // minutes after midnight
  final int closeMinute;
  const DayHours(this.openMinute, this.closeMinute);

  static int? _parse(Object? v) {
    if (v is! String) return null;
    final parts = v.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static DayHours? fromMap(Object? m) {
    if (m is! Map) return null;
    final o = _parse(m['open']), c = _parse(m['close']);
    if (o == null || c == null || c <= o) return null;
    return DayHours(o, c);
  }

  static String _hhmm(int minute) =>
      '${(minute ~/ 60).toString().padLeft(2, '0')}:'
      '${(minute % 60).toString().padLeft(2, '0')}';

  Map<String, String> toMap() =>
      {'open': _hhmm(openMinute), 'close': _hhmm(closeMinute)};

  bool contains(int minuteOfDay) =>
      minuteOfDay >= openMinute && minuteOfDay < closeMinute;
}

/// "7:00 AM" style label for minutes after midnight.
String fmtMinuteOfDay(int minute) {
  final h = minute ~/ 60, m = minute % 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}

const kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

Map<int, DayHours> _parseHours(Object? raw) {
  final out = <int, DayHours>{};
  if (raw is! Map) return out;
  raw.forEach((k, v) {
    final day = int.tryParse('$k');
    final h = DayHours.fromMap(v);
    if (day != null && day >= 1 && day <= 7 && h != null) out[day] = h;
  });
  return out;
}

// ---------------------------------------------------------------------------
// Vendor/stall (Firestore: vendors/{autoId})
// ---------------------------------------------------------------------------
class Vendor {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? gcashNumber;
  final String? gcashName;
  final String? pickupPoint;
  final bool isVerified;
  /// Manual master switch ("accepting orders"). See [isOpenAt].
  final bool isOpen;
  final DateTime? createdAt;

  /// Weekly schedule; empty = no schedule.
  final Map<int, DayHours> hours;

  /// Typical minutes to prepare one order; drives wait estimates.
  final int prepMinutes;

  /// Review aggregates (sum of stars / number of reviews).
  final int ratingSum;
  final int ratingCount;

  /// Loyalty stamp card: one stamp per picked-up order; [loyaltyStamps]
  /// stamps earn [loyaltyReward] (e.g. "a free Iced Tea").
  final bool loyaltyEnabled;
  final int loyaltyStamps;
  final String? loyaltyReward;

  /// Emails (lowercase) of staff accounts allowed to run this stall's
  /// orders and menu availability. Managed by the owner in Settings.
  final List<String> staffEmails;

  const Vendor({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.logoUrl,
    this.gcashNumber,
    this.gcashName,
    this.pickupPoint,
    this.isVerified = false,
    this.isOpen = false,
    this.createdAt,
    this.hours = const {},
    this.prepMinutes = kDefaultPrepMinutes,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.loyaltyEnabled = false,
    this.loyaltyStamps = 10,
    this.loyaltyReward,
    this.staffEmails = const [],
  });

  static const kDefaultPrepMinutes = 10;

  bool get hasLoyalty =>
      loyaltyEnabled && (loyaltyReward?.trim().isNotEmpty ?? false);

  double? get rating => ratingCount == 0 ? null : ratingSum / ratingCount;

  bool get hasSchedule => hours.isNotEmpty;

  /// Taking orders at [t]: switched on AND (no schedule OR inside that day's
  /// hours).
  bool isOpenAt(DateTime t) {
    if (!isOpen) return false;
    if (!hasSchedule) return true;
    return hours[t.weekday]?.contains(t.hour * 60 + t.minute) ?? false;
  }

  bool get isOpenNow => isOpenAt(DateTime.now());

  /// "Closes 5:00 PM" / "Opens Tue 7:00 AM" / null when nothing to say.
  String? hoursLabel(DateTime t) {
    if (!hasSchedule) return null;
    if (isOpenAt(t)) {
      return 'Closes ${fmtMinuteOfDay(hours[t.weekday]!.closeMinute)}';
    }
    if (!isOpen) return null; // manually closed: no promise to make
    final today = hours[t.weekday];
    if (today != null && t.hour * 60 + t.minute < today.openMinute) {
      return 'Opens ${fmtMinuteOfDay(today.openMinute)}';
    }
    for (var i = 1; i <= 7; i++) {
      final day = (t.weekday - 1 + i) % 7 + 1;
      final h = hours[day];
      if (h != null) {
        final when = i == 1 ? 'tomorrow' : kWeekdayShort[day - 1];
        return 'Opens $when ${fmtMinuteOfDay(h.openMinute)}';
      }
    }
    return null;
  }

  factory Vendor.fromMap(String id, Map<String, dynamic> m) => Vendor(
        id: id,
        ownerId: (m['ownerId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        description: m['description'] as String?,
        logoUrl: m['logoUrl'] as String?,
        gcashNumber: m['gcashNumber'] as String?,
        gcashName: m['gcashName'] as String?,
        pickupPoint: m['pickupPoint'] as String?,
        isVerified: (m['isVerified'] ?? false) == true,
        isOpen: (m['isOpen'] ?? false) == true,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        hours: _parseHours(m['hours']),
        prepMinutes:
            (m['prepMinutes'] as num?)?.toInt() ?? kDefaultPrepMinutes,
        ratingSum: (m['ratingSum'] as num?)?.toInt() ?? 0,
        ratingCount: (m['ratingCount'] as num?)?.toInt() ?? 0,
        loyaltyEnabled: m['loyaltyEnabled'] == true,
        loyaltyStamps: (m['loyaltyStamps'] as num?)?.toInt() ?? 10,
        loyaltyReward: m['loyaltyReward'] as String?,
        staffEmails: [
          for (final e in (m['staffEmails'] as List? ?? const []))
            if (e is String) e,
        ],
      );
}

/// A student's stamp card at one stall (Firestore: loyalty/{vendorId}_{uid}).
/// Only the stall writes it: +1 on each picked-up order, minus the card
/// size when the reward is handed over.
class LoyaltyCard {
  final String vendorId;
  final String customerId;
  final int stamps;
  final int redeemed;

  const LoyaltyCard({
    required this.vendorId,
    required this.customerId,
    this.stamps = 0,
    this.redeemed = 0,
  });

  factory LoyaltyCard.fromMap(Map<String, dynamic> m) => LoyaltyCard(
        vendorId: (m['vendorId'] ?? '') as String,
        customerId: (m['customerId'] ?? '') as String,
        stamps: (m['stamps'] as num?)?.toInt() ?? 0,
        redeemed: (m['redeemed'] as num?)?.toInt() ?? 0,
      );
}

/// Vendor with owner info joined in code (admin lists).
class VendorWithOwner extends Vendor {
  final String ownerEmail;
  final String ownerName;

  const VendorWithOwner({
    required super.id,
    required super.ownerId,
    required super.name,
    required this.ownerEmail,
    required this.ownerName,
    super.description,
    super.logoUrl,
    super.gcashNumber,
    super.gcashName,
    super.pickupPoint,
    super.isVerified,
    super.isOpen,
    super.createdAt,
    super.hours,
    super.prepMinutes,
    super.ratingSum,
    super.ratingCount,
    super.loyaltyEnabled,
    super.loyaltyStamps,
    super.loyaltyReward,
    super.staffEmails,
  });

  factory VendorWithOwner.fromMaps(
    String vendorId,
    Map<String, dynamic> vendor,
    Map<String, dynamic>? owner,
  ) {
    final v = Vendor.fromMap(vendorId, vendor);
    return VendorWithOwner(
      id: v.id,
      ownerId: v.ownerId,
      name: v.name,
      ownerEmail: (owner?['email'] ?? '') as String,
      ownerName: (owner?['fullName'] ?? '') as String,
      description: v.description,
      logoUrl: v.logoUrl,
      gcashNumber: v.gcashNumber,
      gcashName: v.gcashName,
      pickupPoint: v.pickupPoint,
      isVerified: v.isVerified,
      isOpen: v.isOpen,
      createdAt: v.createdAt,
      hours: v.hours,
      prepMinutes: v.prepMinutes,
      ratingSum: v.ratingSum,
      ratingCount: v.ratingCount,
      loyaltyEnabled: v.loyaltyEnabled,
      loyaltyStamps: v.loyaltyStamps,
      loyaltyReward: v.loyaltyReward,
      staffEmails: v.staffEmails,
    );
  }
}

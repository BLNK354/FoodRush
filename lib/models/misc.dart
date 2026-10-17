import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ---------------------------------------------------------------------------
// Review (Firestore: reviews/{orderId} — one review per order)
// ---------------------------------------------------------------------------
class Review {
  final String id;
  final String orderId;
  final String customerId;
  final String vendorId;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final String? customerName; // denormalized

  /// The stall's public reply, if any.
  final String? reply;
  final DateTime? repliedAt;

  const Review({
    required this.id,
    required this.orderId,
    required this.customerId,
    required this.vendorId,
    required this.rating,
    this.comment,
    this.createdAt,
    this.customerName,
    this.reply,
    this.repliedAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic> m) => Review(
        id: id,
        orderId: (m['orderId'] ?? '') as String,
        customerId: (m['customerId'] ?? '') as String,
        vendorId: (m['vendorId'] ?? '') as String,
        rating: ((m['rating'] ?? 5) as num).toInt(),
        comment: m['comment'] as String?,
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        customerName: m['customerName'] as String?,
        reply: m['reply'] as String?,
        repliedAt: (m['repliedAt'] as Timestamp?)?.toDate(),
      );
}

// ---------------------------------------------------------------------------
// Announcement (Firestore: settings/announcement) — admin banner for everyone
// ---------------------------------------------------------------------------
class Announcement {
  final String message;
  final bool active;
  final String level; // info | warning
  final DateTime? updatedAt;

  const Announcement({
    required this.message,
    this.active = false,
    this.level = 'info',
    this.updatedAt,
  });

  bool get visible => active && message.trim().isNotEmpty;

  factory Announcement.fromMap(Map<String, dynamic>? m) => Announcement(
        message: (m?['message'] ?? '') as String,
        active: m?['active'] == true,
        level: (m?['level'] ?? 'info') as String,
        updatedAt: (m?['updatedAt'] as Timestamp?)?.toDate(),
      );
}

// ---------------------------------------------------------------------------
// HomeContent (Firestore: settings/home) — admin-edited Shop hero copy.
// Empty fields fall back to the built-in (translated) defaults.
// ---------------------------------------------------------------------------
class HomeContent {
  final String heroTitle;
  final String heroSubtitle;

  const HomeContent({this.heroTitle = '', this.heroSubtitle = ''});

  factory HomeContent.fromMap(Map<String, dynamic>? m) => HomeContent(
        heroTitle: (m?['heroTitle'] ?? '') as String,
        heroSubtitle: (m?['heroSubtitle'] ?? '') as String,
      );
}

// ---------------------------------------------------------------------------
// HomeBanner (Firestore: banners/{autoId}) — promo cards on the Shop page
// ---------------------------------------------------------------------------
class HomeBanner {
  /// Background looks the admin can pick (keep in sync with firestore.rules).
  static const styles = ['ember', 'sunset', 'night', 'mint'];

  final String id; // empty = not saved yet
  final String title;
  final String? body;
  final String? ctaLabel;

  /// In-app route the button opens, e.g. /stall/abc or /orders.
  final String? link;
  final String? imageUrl;
  final String style;
  final bool active;
  final int order;

  const HomeBanner({
    this.id = '',
    required this.title,
    this.body,
    this.ctaLabel,
    this.link,
    this.imageUrl,
    this.style = 'ember',
    this.active = true,
    this.order = 0,
  });

  factory HomeBanner.fromMap(String id, Map<String, dynamic> m) => HomeBanner(
        id: id,
        title: (m['title'] ?? '') as String,
        body: m['body'] as String?,
        ctaLabel: m['ctaLabel'] as String?,
        link: m['link'] as String?,
        imageUrl: m['imageUrl'] as String?,
        style: styles.contains(m['style']) ? m['style'] as String : 'ember',
        active: m['active'] == true,
        order: ((m['order'] ?? 0) as num).toInt(),
      );

  Map<String, dynamic> toMap() => {
        'title': title.trim(),
        'body': _orNull(body),
        'ctaLabel': _orNull(ctaLabel),
        'link': _orNull(link),
        'imageUrl': _orNull(imageUrl),
        'style': style,
        'active': active,
        'order': order,
      };

  static String? _orNull(String? v) =>
      v == null || v.trim().isEmpty ? null : v.trim();

  HomeBanner copyWith({bool? active, int? order}) => HomeBanner(
        id: id,
        title: title,
        body: body,
        ctaLabel: ctaLabel,
        link: link,
        imageUrl: imageUrl,
        style: style,
        active: active ?? this.active,
        order: order ?? this.order,
      );
}

// ---------------------------------------------------------------------------
// Promotion (Firestore: promotions/{autoId}; vendorId null = platform-wide)
// ---------------------------------------------------------------------------
class Promotion {
  final String id;
  final String? vendorId;
  final String code;
  final String discountType; // percent | fixed
  final double discountValue;
  final double? minOrder;
  final bool isActive;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const Promotion({
    required this.id,
    this.vendorId,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minOrder,
    this.isActive = true,
    this.startsAt,
    this.endsAt,
  });

  bool get isPlatformWide => vendorId == null;

  factory Promotion.fromMap(String id, Map<String, dynamic> m) => Promotion(
        id: id,
        vendorId: m['vendorId'] as String?,
        code: (m['code'] ?? '') as String,
        discountType: (m['discountType'] ?? 'percent') as String,
        discountValue: ((m['discountValue'] ?? 0) as num).toDouble(),
        minOrder: (m['minOrder'] as num?)?.toDouble(),
        isActive: (m['isActive'] ?? true) == true,
        startsAt: (m['startsAt'] as Timestamp?)?.toDate(),
        endsAt: (m['endsAt'] as Timestamp?)?.toDate(),
      );
}

/// Result of an in-app promo check (replaces the SQL RPC).
class PromoResult {
  final bool valid;
  final double discount;
  final String message;

  const PromoResult({
    required this.valid,
    required this.discount,
    required this.message,
  });
}

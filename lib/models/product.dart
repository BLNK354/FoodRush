import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

// ---------------------------------------------------------------------------
// Category (Firestore: vendors/{vendorId}/categories/{autoId})
// ---------------------------------------------------------------------------
class ProductCategory {
  final String id;
  final String vendorId;
  final String name;
  final int sort;

  const ProductCategory({
    required this.id,
    required this.vendorId,
    required this.name,
    this.sort = 0,
  });

  factory ProductCategory.fromMap(String id, Map<String, dynamic> m) =>
      ProductCategory(
        id: id,
        vendorId: (m['vendorId'] ?? '') as String,
        name: (m['name'] ?? '') as String,
        sort: ((m['sort'] ?? 0) as num).toInt(),
      );
}

// ---------------------------------------------------------------------------
// Add-on: an optional extra a student can tick, e.g. "Extra rice" +₱15.
// ---------------------------------------------------------------------------
class Addon {
  final String name;
  final double price; // may be 0 ("No onions")
  const Addon(this.name, this.price);

  Map<String, dynamic> toMap() => {'name': name, 'price': price};

  static Addon? fromMap(Object? m) {
    if (m is! Map || m['name'] is! String) return null;
    return Addon(m['name'] as String, ((m['price'] ?? 0) as num).toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is Addon && other.name == name && other.price == price;
  @override
  int get hashCode => Object.hash(name, price);
}

/// Most add-ons one product can offer (rules allow 10).
const kMaxAddons = 10;

/// Dietary/feature tags a stall can put on a product.
const kProductTags = ['halal', 'vegetarian', 'spicy', 'bestseller'];

// ---------------------------------------------------------------------------
// Product (Firestore: vendors/{vendorId}/products/{autoId})
// ---------------------------------------------------------------------------
class Product {
  final String id;
  final String vendorId;
  final String? categoryId;
  final String name;
  final String? description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? stockQty;
  final DateTime? createdAt;

  /// Optional extras (max 10) and tags from [kProductTags].
  final List<Addon> addons;
  final List<String> tags;

  const Product({
    required this.id,
    required this.vendorId,
    this.categoryId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.isAvailable = true,
    this.stockQty,
    this.createdAt,
    this.addons = const [],
    this.tags = const [],
  });

  /// Price of one item with the chosen [selected] add-ons. Unknown add-on
  /// names (removed from the menu since) return null.
  double? priceWith(List<String> selected) {
    var total = price;
    for (final name in selected) {
      final a = addons.where((x) => x.name == name);
      if (a.isEmpty) return null;
      total += a.first.price;
    }
    return double.parse(total.toStringAsFixed(2));
  }

  factory Product.fromMap(String id, Map<String, dynamic> m) => Product(
        id: id,
        vendorId: (m['vendorId'] ?? '') as String,
        categoryId: m['categoryId'] as String?,
        name: (m['name'] ?? '') as String,
        description: m['description'] as String?,
        price: ((m['price'] ?? 0) as num).toDouble(),
        imageUrl: m['imageUrl'] as String?,
        isAvailable: (m['isAvailable'] ?? true) == true,
        stockQty: (m['stockQty'] as num?)?.toInt(),
        createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
        addons: [
          for (final a in (m['addons'] as List? ?? const []))
            if (Addon.fromMap(a) case final addon?) addon,
        ],
        tags: [
          for (final t in (m['tags'] as List? ?? const []))
            if (t is String && kProductTags.contains(t)) t,
        ],
      );
}

/// Product with its stall's name/open flag joined in code.
class ProductWithVendor extends Product {
  final String vendorName;
  final bool vendorIsOpen;

  const ProductWithVendor({
    required super.id,
    required super.vendorId,
    required this.vendorName,
    required this.vendorIsOpen,
    super.categoryId,
    required super.name,
    super.description,
    required super.price,
    super.imageUrl,
    super.isAvailable,
    super.stockQty,
    super.createdAt,
  });
}

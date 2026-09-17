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
  });

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

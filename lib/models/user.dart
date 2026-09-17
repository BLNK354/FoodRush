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
  final bool isOpen;
  final DateTime? createdAt;

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
  });

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
  });

  factory VendorWithOwner.fromMaps(
    String vendorId,
    Map<String, dynamic> vendor,
    Map<String, dynamic>? owner,
  ) =>
      VendorWithOwner(
        id: vendorId,
        ownerId: (vendor['ownerId'] ?? '') as String,
        name: (vendor['name'] ?? '') as String,
        ownerEmail: (owner?['email'] ?? '') as String,
        ownerName: (owner?['fullName'] ?? '') as String,
        description: vendor['description'] as String?,
        logoUrl: vendor['logoUrl'] as String?,
        gcashNumber: vendor['gcashNumber'] as String?,
        gcashName: vendor['gcashName'] as String?,
        pickupPoint: vendor['pickupPoint'] as String?,
        isVerified: (vendor['isVerified'] ?? false) == true,
        isOpen: (vendor['isOpen'] ?? false) == true,
        createdAt: (vendor['createdAt'] as Timestamp?)?.toDate(),
      );
}

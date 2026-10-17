// FoodRush app-wide constants.
library;

// ---------------------------------------------------------------------------
// Firebase web config (Firebase console → Project settings → Your apps → Web
// app). These are the project's real values, compiled in like a FlutterFire
// firebase_options.dart. They are NOT secrets: every visitor's browser gets
// them in main.dart.js; access is controlled by firebase/firestore.rules.
// A build may still override any of them with --dart-define=FIREBASE_...=...
// ---------------------------------------------------------------------------
const String kFirebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: 'AIzaSyBCZ3Vxm_JkhaZJpGcaiYty6wVmwwR1JKs',
);
const String kFirebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'foodrush-5f29f',
);
const String kFirebaseAppId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: '1:276031798967:web:787f78eed11854dc0d9732',
);
const String kFirebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: '276031798967',
);
const String kFirebaseAuthDomain = String.fromEnvironment(
  'FIREBASE_AUTH_DOMAIN',
  defaultValue: 'foodrush-5f29f.firebaseapp.com',
);
const String kFirebaseStorageBucket = String.fromEnvironment(
  'FIREBASE_STORAGE_BUCKET',
  defaultValue: 'foodrush-5f29f.firebasestorage.app',
);

/// Local testing switch: talk to the Firebase emulators instead of the live
/// project (see main.dart). Off in every normal build.
const bool kUseEmulators = bool.fromEnvironment('USE_EMULATORS');

// ---------------------------------------------------------------------------
// University gate
// ---------------------------------------------------------------------------
const String kUniversityDomain = 'lpunetwork.edu.ph';
const String kUniversityName = 'LPU';

bool isLpuEmail(String email) {
  final e = email.trim().toLowerCase();
  return e.endsWith('@$kUniversityDomain');
}

// ---------------------------------------------------------------------------
// Roles
// ---------------------------------------------------------------------------
const String kRoleCustomer = 'customer';
const String kRoleVendor = 'vendor';
const String kRoleAdmin = 'admin';

/// Works a stall's orders/menu for an owner who listed their email; has no
/// stall of their own.
const String kRoleStaff = 'staff';

const String kColLoyalty = 'loyalty';

// ---------------------------------------------------------------------------
// Payment
// ---------------------------------------------------------------------------
const String kPayGcash = 'gcash';
const String kPayCash = 'cash';

const Map<String, String> kPaymentLabels = {
  kPayGcash: 'GCash (pay now, upload receipt)',
  kPayCash: 'Cash (pay at pickup)',
};

// ---------------------------------------------------------------------------
// Order status flow (pickup-only, no delivery)
// awaiting_payment -> proof_submitted -> accepted -> preparing -> ready -> completed
// ---------------------------------------------------------------------------
const String kOrderAwaitingPayment = 'awaiting_payment';
const String kOrderProofSubmitted = 'proof_submitted';
const String kOrderAccepted = 'accepted';
const String kOrderPreparing = 'preparing';
const String kOrderReady = 'ready';
const String kOrderCompleted = 'completed';
const String kOrderRejected = 'rejected';
const String kOrderCancelled = 'cancelled';

const List<String> kOrderStatusFlow = [
  kOrderAwaitingPayment,
  kOrderProofSubmitted,
  kOrderAccepted,
  kOrderPreparing,
  kOrderReady,
  kOrderCompleted,
];

const Map<String, String> kOrderStatusLabels = {
  kOrderAwaitingPayment: 'Awaiting payment',
  kOrderProofSubmitted: 'Receipt submitted',
  kOrderAccepted: 'Accepted',
  kOrderPreparing: 'Preparing',
  kOrderReady: 'Ready for pickup',
  kOrderCompleted: 'Completed',
  kOrderRejected: 'Rejected',
  kOrderCancelled: 'Cancelled',
};

// ---------------------------------------------------------------------------
// Payment proof verification
// ---------------------------------------------------------------------------
const String kProofPending = 'pending';
const String kProofVerified = 'verified';
const String kProofRejected = 'rejected';

// ---------------------------------------------------------------------------
// Storage paths (Firebase Storage)
// ---------------------------------------------------------------------------
const String kPathProductImages = 'product-images';
const String kPathVendorLogos = 'vendor-logos';
const String kPathPaymentProofs = 'payment-proofs';

// ---------------------------------------------------------------------------
// Firestore collections
// ---------------------------------------------------------------------------
const String kColUsers = 'users';
const String kColVerifyLinks = 'verifyLinks';

/// Verification email links stop working this long after they are sent
/// (enforced by the in-app link page, see lib/features/auth/auth_action_screen.dart).
const Duration kVerifyLinkLifetime = Duration(minutes: 15);

/// Most verification emails per rolling hour, and the gap between them
/// (the security rules enforce both).
const int kVerifySendsPerHour = 5;
const Duration kVerifyResendGap = Duration(seconds: 60);
const String kColVendors = 'vendors';
const String kColCategories = 'categories';
const String kColProducts = 'products';
const String kColOrders = 'orders';
const String kColReviews = 'reviews';
const String kColFavorites = 'favorites';
const String kColPromotions = 'promotions';
const String kColSettings = 'settings';
const String kColCounters = 'counters';
const String kColBanners = 'banners';

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------
const String kAppName = 'FoodRush';

/// Shown on the privacy notice for privacy requests. Fill in the address
/// your admins actually read (left blank, the contact line is hidden).
const String kSupportEmail = '';

/// Replaces a deleted student's name on past orders and reviews.
const String kDeletedUserName = 'Deleted user';
const String kCurrencySymbol = '₱';
const int kMinPasswordLength = 8;
const int kMaxCartQty = 99;
const String kDefaultPickupNote =
    'Claim at the stall counter. Show your queue number.';
const String kSettingsDocPlatformGcash = 'platform_gcash';
const String kSettingsDocAnnouncement = 'announcement';
const String kSettingsDocHome = 'home';

/// Minimum gap between two orders by the same student (enforced by rules).
const Duration kOrderCooldown = Duration(seconds: 30);

/// Products at or below this stock show as "running low" to the stall.
const int kLowStockThreshold = 5;
const String kDeactivatedNotice =
    'This account has been deactivated. Contact a FoodRush admin.';

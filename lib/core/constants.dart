// FoodRush app-wide constants.
library;

// ---------------------------------------------------------------------------
// Firebase — supplied at build time via --dart-define (web config values from
// Firebase console → Project settings → Your apps → Web app).
// flutter run -d web-server \
//   --dart-define=FIREBASE_API_KEY=... \
//   --dart-define=FIREBASE_PROJECT_ID=... \
//   --dart-define=FIREBASE_APP_ID=... \
//   --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
// ---------------------------------------------------------------------------
const String kFirebaseApiKey = String.fromEnvironment(
  'FIREBASE_API_KEY',
  defaultValue: 'YOUR-API-KEY',
);
const String kFirebaseProjectId = String.fromEnvironment(
  'FIREBASE_PROJECT_ID',
  defaultValue: 'YOUR-PROJECT-ID',
);
const String kFirebaseAppId = String.fromEnvironment(
  'FIREBASE_APP_ID',
  defaultValue: 'YOUR-APP-ID',
);
const String kFirebaseMessagingSenderId = String.fromEnvironment(
  'FIREBASE_MESSAGING_SENDER_ID',
  defaultValue: 'YOUR-SENDER-ID',
);
const String kFirebaseAuthDomain = String.fromEnvironment(
  'FIREBASE_AUTH_DOMAIN',
  defaultValue: 'YOUR-PROJECT-ID.firebaseapp.com',
);
const String kFirebaseStorageBucket = String.fromEnvironment(
  'FIREBASE_STORAGE_BUCKET',
  defaultValue: 'YOUR-PROJECT-ID.appspot.com',
);

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
const String kColVendors = 'vendors';
const String kColCategories = 'categories';
const String kColProducts = 'products';
const String kColOrders = 'orders';
const String kColReviews = 'reviews';
const String kColFavorites = 'favorites';
const String kColPromotions = 'promotions';
const String kColSettings = 'settings';
const String kColCounters = 'counters';

// ---------------------------------------------------------------------------
// Misc
// ---------------------------------------------------------------------------
const String kAppName = 'FoodRush';
const String kCurrencySymbol = '₱';
const int kMinPasswordLength = 8;
const int kMaxCartQty = 99;
const String kDefaultPickupNote =
    'Claim at the stall counter. Show your queue number.';
const String kSettingsDocPlatformGcash = 'platform_gcash';

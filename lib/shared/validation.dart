/// Input checks shared by every form, so the same rules apply everywhere.
///
/// Validators return an error message, or null when the value is fine
/// (the shape Flutter's `validator:` expects). Length limits here mirror
/// firebase/firestore.rules: the app explains, the rules enforce.
library;

// ---------------------------------------------------------------------------
// Limits (keep in sync with firestore.rules)
// ---------------------------------------------------------------------------
abstract final class Limits {
  static const name = 60; // people & stalls
  static const email = 120;
  static const password = 128;
  static const phone = 13; // +639XXXXXXXXX
  static const studentNumber = 20;
  static const productName = 80;
  static const description = 300;
  static const pickupPoint = 120;
  static const categoryName = 40;
  static const note = 200; // order note, reject/cancel reasons
  static const review = 500;
  static const reply = 300;
  static const announcement = 280;
  static const search = 100;
  static const promoCode = 20;
  static const addonName = 30;
  static const reward = 60;
  static const maxAddonPrice = 1000.0;

  static const maxPrice = 10000.0; // ₱ per item
  static const maxStock = 9999;
  static const maxFixedDiscount = 10000.0;
  static const maxMinOrder = 100000.0;
}

// ---------------------------------------------------------------------------
// Bad-word filter (English + Filipino). Client-side only: the database can't
// run it, so it stops honest typos and casual trolls, not a determined
// attacker calling the API (whose text is still length-limited by rules).
// ---------------------------------------------------------------------------

/// Matched anywhere, even inside other text ("putanginamo", "fuuuck").
const _badAnywhere = {
  'fuck', 'motherfuck', 'bullshit', 'shitty', 'bitch', 'nigger', 'nigga', 'faggot',
  'asshole', 'bastard', 'whore', 'putangina', 'tangina', 'tanginamo',
  'kingina', 'pakyu', 'pakshet', 'punyeta', 'tarantado', 'hindot', 'kantot',
  // vowel-dropped spellings people use to dodge filters
  'tangna', 'tngina', 'tnginamo', 'putangna', 'ptangina', 'pakingshet',
  'jakol', 'burat', 'kupal', 'pokpok',
};

/// Matched only as whole words (short ones that hide inside normal words).
const _badWords = {
  'fck', 'fk', 'fuk', 'wtf', 'stfu', 'dick', 'pussy', 'slut', 'cock', 'puta',
  'shit', 'shits', 'sht', 'cunt', 'cunts',
  'gago', 'gaga', 'tanga', 'bobo', 'ulol', 'ulul', 'tite', 'titi', 'puke',
  'leche', 'yawa', 'pisti', 'inutil', 'tngina', 'tnga', 'pucha',
};

/// Real words that contain a blocked one ("the Scunthorpe problem"); removed
/// before matching so they never trip the filter.
const _allowed = {
  'shiitake', 'scunthorpe', 'cocktail', 'cockpit', 'peacock', 'hancock',
  'assessment', 'passion', 'classic', 'dickens', 'therapist', 'matsutake',
};

/// Letters people swap in to dodge filters.
const _leet = {
  '0': 'o', '1': 'i', '!': 'i', '3': 'e', '4': 'a', '@': 'a', '5': 's',
  r'$': 's', '7': 't', '8': 'b', '9': 'g', '+': 't',
};

String _collapse(String s) =>
    s.replaceAllMapped(RegExp(r'(.)\1+'), (m) => m.group(1)!);

final Set<String> _anywhere = {for (final w in _badAnywhere) _collapse(w)};
final Set<String> _whole = {for (final w in _badWords) _collapse(w)};

/// True if [text] contains a blocked word (also leetspeak, repeated
/// letters, and spaced-out "f u c k").
bool containsBadWords(String text) {
  var t = text.toLowerCase();
  for (final w in _allowed) {
    t = t.replaceAll(w, ' ');
  }
  t = t.split('').map((c) => _leet[c] ?? c).join();
  t = t.replaceAll(RegExp(r'[^a-zñ\s]'), ''); // drop * . - _ etc.
  // Re-join letters spaced out one by one: "f u c k" -> "fuck".
  t = t.replaceAllMapped(
      RegExp(r'\b(?:[a-zñ]\s+){2,}[a-zñ]\b'), (m) => m[0]!.replaceAll(RegExp(r'\s+'), ''));
  final collapsed = _collapse(t);
  final squashed = collapsed.replaceAll(RegExp(r'\s+'), '');
  if (_anywhere.any(squashed.contains)) return true;
  final words = collapsed.split(RegExp(r'\s+'));
  return words.any(_whole.contains);
}

const _badWordMessage = 'Please keep it clean: that contains a blocked word.';

// ---------------------------------------------------------------------------
// Validators
// ---------------------------------------------------------------------------

/// Free text: optional unless [required]; max length; no bad words; and not
/// just repeated junk ("aaaaaaaa", "!!!!!!!!").
String? validateText(
  String? v, {
  required int max,
  bool required = false,
  int min = 1,
  String label = 'This',
}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return required ? '$label is required' : null;
  if (s.length < min) return '$label must be at least $min characters';
  if (s.length > max) return '$label must be at most $max characters';
  if (s.length >= 8 && RegExp(r'^(.)\1+$').hasMatch(s.replaceAll(' ', ''))) {
    return '$label looks like spam';
  }
  if (containsBadWords(s)) return _badWordMessage;
  return null;
}

/// A person's name: letters (any language), spaces, . ' -
String? validatePersonName(String? v) {
  final err = validateText(v, max: Limits.name, required: true, min: 2, label: 'Name');
  if (err != null) return err;
  if (!RegExp(r"^[\p{L} .'\-]+$", unicode: true).hasMatch(v!.trim())) {
    return 'Use letters only (no numbers or symbols)';
  }
  return null;
}

String? validateEmail(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Email is required';
  if (s.length > Limits.email) return 'Email is too long';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
    return 'Enter a valid email address';
  }
  return null;
}

/// Philippine mobile: 09XXXXXXXXX or +639XXXXXXXXX (spaces/dashes ignored).
String? validatePhone(String? v, {bool required = false, String label = 'Mobile number'}) {
  final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
  if (s.isEmpty) return required ? '$label is required' : null;
  if (!RegExp(r'^(09\d{9}|\+639\d{9})$').hasMatch(s)) {
    return 'Use 09XXXXXXXXX (11 digits)';
  }
  return null;
}

/// Student number: digits and dashes, e.g. 2023-2-01664.
/// Students must give one (the stall checks it at pickup); the security
/// rules enforce the same 4-20 digits-and-dashes shape.
String? validateStudentNumber(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Student number is required';
  if (s.length > Limits.studentNumber) return 'Student number is too long';
  if (!RegExp(r'^[0-9-]+$').hasMatch(s)) return 'Digits and dashes only';
  if (s.replaceAll('-', '').length < 4) return 'Student number is too short';
  return null;
}

/// Money: a real number in (0, max], at most 2 decimals. Rejects "NaN",
/// "Infinity", "1e9", negatives, zero.
String? validateMoney(String? v, {double max = Limits.maxPrice, bool allowZero = false,
    bool required = true, String label = 'Price'}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return required ? '$label is required' : null;
  if (!RegExp(r'^\d{1,7}(\.\d{1,2})?$').hasMatch(s)) {
    return 'Enter an amount like 75 or 75.50';
  }
  final n = double.parse(s);
  if (n == 0 && !allowZero) return '$label must be more than ₱0';
  if (n > max) return '$label can be at most ₱${max.toStringAsFixed(0)}';
  return null;
}

/// Whole number in [min, max]; blank allowed unless [required].
String? validateWholeNumber(String? v,
    {required int min, required int max, bool required = false, String label = 'Value'}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return required ? '$label is required' : null;
  if (!RegExp(r'^\d{1,6}$').hasMatch(s)) return 'Whole numbers only';
  final n = int.parse(s);
  if (n < min || n > max) return '$label must be between $min and $max';
  return null;
}

/// Promo codes: 3-20 letters/digits (stored uppercase).
String? validatePromoCode(String? v) {
  final s = (v ?? '').trim().toUpperCase();
  if (s.isEmpty) return 'Code is required';
  if (!RegExp(r'^[A-Z0-9]{3,20}$').hasMatch(s)) {
    return '3-20 letters or digits, no spaces';
  }
  if (containsBadWords(s)) return _badWordMessage;
  return null;
}

/// First non-null error from [checks], for dialogs that validate on Save.
String? firstError(List<String?> checks) =>
    checks.firstWhere((e) => e != null, orElse: () => null);

/// Discount value for a promo of [type] ('percent' or 'fixed').
String? validateDiscount(String? v, String type) => type == 'percent'
    ? validateWholeNumber(v, min: 1, max: 100, required: true, label: 'Percent off')
    : validateMoney(v, max: Limits.maxFixedDiscount, label: 'Discount');

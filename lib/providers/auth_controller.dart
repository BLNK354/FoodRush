import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../models/user.dart';
import 'repository.dart';

/// Holds the currently authenticated profile (or null).
class AuthData {
  final Profile? profile;
  final bool loading;

  /// Why the user was signed out by the app (e.g. account deactivated);
  /// shown on the login screen.
  final String? notice;

  /// The account's email has been confirmed via Firebase's link. Until it
  /// is, the app shows the verify screen and the rules refuse orders, so
  /// nobody can pose as an LPU student with an inbox they don't own.
  final bool emailVerified;

  const AuthData({
    this.profile,
    this.loading = false,
    this.notice,
    this.emailVerified = false,
  });

  bool get isAuthenticated => profile != null;
  String? get role => profile?.role;
}

class AuthController extends Notifier<AuthData> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  Timer? _missingDocTimer;

  /// uid whose profile is currently being watched (null = signed out).
  String? _uid;

  /// Completes when the watched uid's profile first resolves.
  Completer<void>? _profileReady;

  @override
  AuthData build() {
    ref.onDispose(() {
      _authSub?.cancel();
      _stopProfile();
    });
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onUser);

    // Firebase.initializeApp (web) already waits for the persisted session to
    // be restored, so currentUser is authoritative here — no need to guess
    // from the first stream event or wait on a timer.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const AuthData();
    _watchProfile(user);
    // Loading only during this cold-start profile fetch; sign-in/out later
    // never flips back to loading.
    return const AuthData(loading: true);
  }

  void _onUser(User? user) {
    if (user?.uid == _uid) return; // same session (e.g. the initial replay)
    _stopProfile();
    if (user == null) {
      state = const AuthData();
    } else {
      _watchProfile(user);
    }
  }

  /// Streams users/{uid} live: the doc may not exist yet right after signup
  /// (it's written after the auth account), and role/isActive changes made
  /// by an admin show up without a re-login.
  void _watchProfile(User user) {
    _uid = user.uid;
    final ready = _profileReady = Completer<void>();

    void apply(Profile profile) {
      if (_uid != user.uid) return; // stale: signed out / switched user
      if (!ready.isCompleted) ready.complete();
      if (!profile.isActive) {
        // Deactivated by an admin (at sign-in or mid-session): end the
        // session. The rules also refuse writes from inactive accounts.
        _stopProfile();
        state = const AuthData(notice: kDeactivatedNotice);
        FirebaseAuth.instance.signOut();
        return;
      }
      state = AuthData(
        profile: profile,
        emailVerified:
            FirebaseAuth.instance.currentUser?.emailVerified ?? false,
      );
    }

    Profile fallback() => Profile(
          id: user.uid,
          email: user.email ?? '',
          role: kRoleCustomer,
          fullName: user.displayName ?? '',
        );

    _profileSub = FirebaseFirestore.instance
        .collection(kColUsers)
        .doc(user.uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) {
        // Doc still missing — give signup time to write it, then fall back.
        // If it appears later this listener corrects the profile.
        _missingDocTimer ??=
            Timer(const Duration(seconds: 5), () => apply(fallback()));
        return;
      }
      _missingDocTimer?.cancel();
      _missingDocTimer = null;
      apply(Profile.fromMap(user.uid, data));
    }, onError: (Object _) => apply(fallback()));
  }

  void _stopProfile() {
    _profileSub?.cancel();
    _profileSub = null;
    _missingDocTimer?.cancel();
    _missingDocTimer = null;
    _uid = null;
    _profileReady = null;
  }

  /// Waits (bounded) until the signed-in user's profile is in [state], so
  /// callers' busy spinners cover the whole sign-in and the router redirect
  /// fires with the real role.
  Future<void> _awaitProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // The auth stream may lag the sign-in future; start watching now.
    _onUser(user);
    await _profileReady?.future
        .timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  /// Sign in with email + password.
  Future<String?> signIn(String email, String password) async {
    if (state.notice != null) state = const AuthData();
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      await _awaitProfile();
      return state.isAuthenticated ? null : state.notice;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-credential' || 'wrong-password' || 'user-not-found' =>
          'Invalid email or password.',
        'user-disabled' => 'This account has been disabled.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Sign in failed.',
      };
    } catch (e) {
      return 'Sign in failed: $e';
    }
  }

  /// Register a customer (LPU email enforced) or vendor (with stall details).
  Future<String?> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    String? studentNumber,
    required String role,
    String? stallName,
    String? stallDescription,
  }) async {
    final cleanEmail = email.trim();
    if (role == kRoleCustomer && !isLpuEmail(cleanEmail)) {
      return 'Customers must register with an @$kUniversityDomain email.';
    }
    if (password.length < kMinPasswordLength) {
      return 'Password must be at least $kMinPasswordLength characters.';
    }
    if (role == kRoleVendor &&
        (stallName == null || stallName.trim().isEmpty)) {
      return 'Please enter your stall name.';
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      final uid = cred.user!.uid;
      final displayName = fullName.trim();
      if (displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
      }

      final db = FirebaseFirestore.instance;

      // One-time bootstrap: the first account ever created claims the admin
      // role (allowed by the rules only while no marker doc exists), then
      // writes the marker to close the window forever.
      var effectiveRole = role;
      try {
        final marker =
            await db.collection(kColSettings).doc('app_bootstrapped').get();
        if (!marker.exists) effectiveRole = kRoleAdmin;
      } catch (_) {
        // If the check fails, fall through with the requested role.
      }

      await db.collection(kColUsers).doc(uid).set({
        'email': cleanEmail,
        'role': effectiveRole,
        'fullName': fullName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (studentNumber != null && studentNumber.trim().isNotEmpty)
          'studentNumber': studentNumber.trim(),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (effectiveRole == kRoleAdmin) {
        await Repository.instance.markBootstrapped();
      }

      if (effectiveRole == kRoleVendor) {
        await db.collection(kColVendors).add({
          'ownerId': uid,
          'name': stallName!.trim(),
          if (stallDescription != null && stallDescription.trim().isNotEmpty)
            'description': stallDescription.trim(),
          'isVerified': false,
          'isOpen': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await _awaitProfile();
      // Prove they own the inbox (the LPU gate is meaningless otherwise).
      try {
        await cred.user!.sendEmailVerification();
      } catch (_) {
        // Rate-limited or offline: the verify screen offers "Resend".
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'That email is already registered.';
      }
      if (e.code == 'weak-password') {
        return 'Password is too weak.';
      }
      return e.message ?? 'Registration failed.';
    } catch (e) {
      return 'Registration failed: $e';
    }
  }

  /// Sends Firebase's password-reset email. Returns an error message or null.
  Future<String?> sendPasswordReset(String email) async {
    final clean = email.trim();
    if (clean.isEmpty) return 'Enter your email first.';
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: clean);
      return null;
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        // Don't reveal whether an account exists.
        'user-not-found' => null,
        _ => e.message ?? 'Could not send the reset email.',
      };
    } catch (e) {
      return 'Could not send the reset email: $e';
    }
  }

  /// Updates the signed-in user's own editable fields. The live profile
  /// stream picks up the change, so [state] refreshes by itself.
  Future<void> updateMyProfile({
    required String fullName,
    String? phone,
    String? studentNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String? orNull(String? v) =>
        v == null || v.trim().isEmpty ? null : v.trim();
    await FirebaseFirestore.instance.collection(kColUsers).doc(user.uid).update({
      'fullName': fullName.trim(),
      'phone': orNull(phone),
      'studentNumber': orNull(studentNumber),
    });
    if (fullName.trim().isNotEmpty) {
      await user.updateDisplayName(fullName.trim());
    }
  }

  /// Re-reads the account after the user clicked the link (in any tab or
  /// device) and refreshes the ID token so the rules see email_verified.
  /// Returns true once verified.
  Future<bool> refreshEmailVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload();
    final fresh = FirebaseAuth.instance.currentUser;
    final verified = fresh?.emailVerified ?? false;
    if (verified) await fresh!.getIdToken(true);
    if (state.isAuthenticated && verified != state.emailVerified) {
      state = AuthData(profile: state.profile, emailVerified: verified);
    }
    return verified;
  }

  /// Sends the verification email again. Returns an error message or null.
  Future<String?> resendVerification() async {
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return e.code == 'too-many-requests'
          ? 'Too many emails sent. Wait a few minutes, then try again.'
          : (e.message ?? 'Could not send the email.');
    }
  }

  /// Students only: anonymises their name on past orders and reviews,
  /// deletes favourites, profile and the login. Returns an error or null.
  Future<String?> deleteMyAccount(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return 'Not signed in.';
    if (state.role != kRoleCustomer) {
      return 'Only student accounts can be deleted here. Ask an admin.';
    }
    try {
      // Firebase requires a recent sign-in to delete; this also confirms
      // it's really them.
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'wrong-password' || 'invalid-credential' => 'That password is wrong.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Could not confirm your password.',
      };
    }
    try {
      final blocked = await Repository.instance.anonymiseAndDeleteMyData();
      if (blocked != null) return blocked;
      _stopProfile();
      await user.delete();
      state = const AuthData(notice: 'Your account has been deleted.');
      return null;
    } catch (e) {
      return 'Could not delete the account: $e';
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    _onUser(null);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthData>(AuthController.new);

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

  const AuthData({this.profile, this.loading = false});

  bool get isAuthenticated => profile != null;
  String? get role => profile?.role;
}

class AuthController extends Notifier<AuthData> {
  StreamSubscription<User?>? _sub;

  @override
  AuthData build() {
    _sub?.cancel();
    _sub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        state = const AuthData();
      } else {
        state = const AuthData(loading: true);
        _loadProfile();
      }
    });
    ref.onDispose(() => _sub?.cancel());

    // Stay loading until the FIRST authStateChanges event resolves — on web,
    // Firebase restores the session asynchronously, and reporting "signed out"
    // too early made the router rewrite deep links to /login.
    return const AuthData(loading: true);
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      state = const AuthData();
      return;
    }
    // The users/{uid} doc is written right after signup — retry briefly in
    // case the auth stream fires before the write lands.
    Map<String, dynamic>? data;
    for (var attempt = 0; attempt < 4; attempt++) {
      final snap =
          await FirebaseFirestore.instance.collection(kColUsers).doc(user.uid).get();
      if (snap.exists) {
        data = snap.data();
        break;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }


    if (data != null) {
      state = AuthData(profile: Profile.fromMap(user.uid, data));
      return;
    }
    // Fallback: doc still missing.
    state = AuthData(
      profile: Profile(
        id: user.uid,
        email: user.email ?? '',
        role: kRoleCustomer,
        fullName: user.displayName ?? '',
      ),
    );
  }

  Future<void> refresh() => _loadProfile();

  /// Sign in with email + password.
  Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      await _loadProfile();
      return null;
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

      await _loadProfile();
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

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    state = const AuthData();
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthData>(AuthController.new);

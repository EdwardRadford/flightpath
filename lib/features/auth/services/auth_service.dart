// Authentication service — email/password, Google Sign-In, Apple Sign-In, and password reset.
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:flight_path/shared/services/notification_service.dart';
import 'package:flight_path/shared/services/subscription_service.dart';

/// Wraps Firebase Auth and Google Sign-In for login, signup, and sign-out.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Signs in with email and password.
  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final uid = _auth.currentUser?.uid;
    if (uid != null) await SubscriptionService.identifyUser(uid);
    await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
  }

  /// Creates a new account and initialises the Firestore user document.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (displayName.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-display-name',
        message: 'Display name cannot be empty.',
      );
    }
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user!.updateDisplayName(displayName);
    await _createUserDocument(credential.user!.uid, displayName, email);
    await SubscriptionService.identifyUser(credential.user!.uid);
    await FirebaseAnalytics.instance.logEvent(
      name: 'signup_completed',
      parameters: {'method': 'email'},
    );
  }

  /// Authenticates via Google Sign-In and creates a user doc if needed.
  Future<void> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return; // User cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Sign-in completed but no user was returned. Please try again.',
        );
      }

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _createUserDocument(
          user.uid,
          user.displayName ?? googleUser.displayName ?? '',
          user.email ?? '',
        );
      }
      await SubscriptionService.identifyUser(user.uid);
    } on FirebaseAuthException {
      rethrow;
    } on PlatformException catch (_) {
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Google Sign-In is not available. Please use email sign-in instead.',
      );
    } catch (_) {
      throw FirebaseAuthException(
        code: 'google-signin-failed',
        message: 'Google Sign-In is not available. Please use email sign-in instead.',
      );
    }
  }

  /// Authenticates via Sign In with Apple and creates a user doc if needed.
  Future<void> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(oauthCredential);
      final user = result.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'null-user',
          message: 'Sign-in completed but no user was returned. Please try again.',
        );
      }

      final doc = await _db.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        // Apple only returns name on first sign-in; fall back to email prefix.
        final displayName = [
          appleCredential.givenName,
          appleCredential.familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ');
        final fallback = (user.email ?? '').split('@').first;
        await _createUserDocument(
          user.uid,
          displayName.isNotEmpty ? displayName : fallback,
          user.email ?? '',
        );
      }
      await SubscriptionService.identifyUser(user.uid);
      await FirebaseAnalytics.instance.logLogin(loginMethod: 'apple');
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      throw FirebaseAuthException(
        code: 'apple-signin-failed',
        message: 'Apple Sign-In failed. Please try again.',
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (_) {
      throw FirebaseAuthException(
        code: 'apple-signin-failed',
        message: 'Apple Sign-In failed. Please try again.',
      );
    }
  }

  /// Sends a password-reset email via Firebase Auth.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Signs out of Google, resets RevenueCat session, and signs out of Firebase.
  Future<void> signOut() async {
    await NotificationService.cleanupFcm();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('AuthService sign-out: $e');
    }
    await SubscriptionService.resetUser();
    await _auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  Future<void> _createUserDocument(String uid, String displayName, String email) async {
    final now = Timestamp.now();
    await _db.collection('users').doc(uid).set({
      'display_name': displayName,
      'email': email,
      'hours_flown': 0.0,
      'aircraft_type': '',
      'flight_school': '',
      'airfield_icao': '',
      'subscription_status': 'free',
      'has_purchased': false,
      'granted_access': false,
      'disclaimer_acknowledged': false,
      'user_role': 'student',
      'current_exercise_number': 1,
      'created_at': now,
      'updated_at': now,
    });
    FirebaseAnalytics.instance.logEvent(name: 'account_created');
  }

  /// Maps a [FirebaseAuthException] code to a user-friendly message.
  static String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Check your internet connection.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

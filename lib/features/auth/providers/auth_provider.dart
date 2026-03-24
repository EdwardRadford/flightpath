// Auth state providers — exposes Firebase Auth stream and current UID.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

/// Streams the current Firebase Auth user. Null = not logged in.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Convenience provider for the current user's UID.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Auth service for performing sign in / sign up / sign out.
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

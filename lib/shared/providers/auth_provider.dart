// Auth state providers — exposes Firebase Auth stream and current UID.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Streams the current Firebase Auth user. Null = not logged in.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Convenience provider for the current user's UID.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authStateProvider).valueOrNull?.uid;
});

/// Set to `true` by the instructor login screen so that profile-setup can
/// pre-toggle the instructor switch for brand-new users whose Firestore doc
/// doesn't exist yet (and therefore has no `user_role` field).
final pendingInstructorSignupProvider = StateProvider<bool>((ref) => false);

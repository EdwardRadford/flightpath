// Streams the current user's Firestore profile as an [AppUser].
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_provider.dart';
import '../models/app_user.dart';

/// Streams the current user's Firestore document. Null = not logged in or doc not yet created.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(null);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) {
        if (!snap.exists) return null;
        try {
          return AppUser.fromFirestore(snap);
        } catch (e) {
          // Corrupt or incomplete Firestore document — surface null rather than
          // crashing the stream, which would break the entire app.
          return null;
        }
      });
});

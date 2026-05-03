import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_user_provider.dart';

class NotificationPermissionManager {
  static const String _requestedField = 'notification_permission_requested_at';

  /// Requests FCM permission if the user is ready:
  /// - Has at least one lesson (scheduled or completed), OR
  /// - Has completed all 5 prep steps for any exercise.
  ///
  /// Only requests once — persists the timestamp to Firestore to avoid re-asking.
  static Future<void> requestIfReady(WidgetRef ref) async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final uid = user.uid;
    final db = FirebaseFirestore.instance;

    // Check if already requested
    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.data()?[_requestedField] != null) return;

    // Check trigger conditions
    final lessonsSnap = await db
        .collection('users')
        .doc(uid)
        .collection('lessons')
        .limit(1)
        .get();
    final hasLesson = lessonsSnap.docs.isNotEmpty;

    bool hasCompletedPrep = false;
    if (!hasLesson) {
      final exercisesSnap = await db
          .collection('users')
          .doc(uid)
          .collection('user_exercises')
          .get();
      hasCompletedPrep = exercisesSnap.docs.any((doc) {
        final d = doc.data();
        final steps = d['prep_steps_done'];
        if (steps is Map) return steps.length >= 5;
        return false;
      });
    }

    if (!hasLesson && !hasCompletedPrep) return;

    // Request permission
    await FirebaseMessaging.instance.requestPermission();

    // Record that we've requested
    await db.collection('users').doc(uid).update({
      _requestedField: FieldValue.serverTimestamp(),
    });
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kHasSeenWalkthroughKey = 'has_seen_walkthrough';

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Returns the UID of the currently signed-in user, or null if guest.
String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

/// Reads the walkthrough flag from Firestore for [uid].
/// Returns null if the field does not exist yet.
///
/// Reads both `has_seen_walkthrough` (current) and `hasSeenWalkthrough`
/// (legacy camelCase from pre-rename docs). The next write will clear
/// the legacy field so this fallback eventually goes unused.
Future<bool?> _readFirestore(String uid) async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get(const GetOptions(source: Source.serverAndCache));
  final data = doc.data();
  if (data == null) return null;
  final value = data['has_seen_walkthrough'] ?? data['hasSeenWalkthrough'];
  if (value is bool) return value;
  return null;
}

/// Writes the walkthrough flag to Firestore for [uid].
/// Also deletes the legacy camelCase field if present.
Future<void> _writeFirestore(String uid, bool value) async {
  await FirebaseFirestore.instance.collection('users').doc(uid).set({
    'has_seen_walkthrough': value,
    'hasSeenWalkthrough': FieldValue.delete(),
  }, SetOptions(merge: true));
}

/// One-time migration: if SharedPreferences has the old flag but Firestore
/// does not, copy the value to Firestore and remove the local key.
Future<void> _migrateIfNeeded(String uid) async {
  final prefs = await SharedPreferences.getInstance();
  final localFlag = prefs.getBool(kHasSeenWalkthroughKey);
  if (localFlag == null) return;

  final remoteFlag = await _readFirestore(uid);
  if (remoteFlag == null) {
    await _writeFirestore(uid, localFlag);
  }
  await prefs.remove(kHasSeenWalkthroughKey);
}

/// Reads the definitive walkthrough state, handling migration and guest fallback.
Future<bool> _resolveWalkthroughState() async {
  final uid = _currentUid();

  if (uid == null) {
    // Guest: fall back to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kHasSeenWalkthroughKey) ?? false;
  }

  // Signed-in: migrate local flag if present, then read Firestore.
  await _migrateIfNeeded(uid);
  final remote = await _readFirestore(uid);
  return remote ?? false;
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Whether the home-screen walkthrough has been completed (or skipped).
final walkthroughCompleteProvider = FutureProvider<bool>((ref) async {
  return _resolveWalkthroughState();
});

/// Notifier that persists walkthrough completion state.
/// Signed-in users → Firestore. Guests → SharedPreferences.
final walkthroughNotifierProvider =
    AsyncNotifierProvider<WalkthroughNotifier, bool>(WalkthroughNotifier.new);

class WalkthroughNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return _resolveWalkthroughState();
  }

  Future<void> markComplete() async {
    final uid = _currentUid();
    if (uid != null) {
      await _writeFirestore(uid, true);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kHasSeenWalkthroughKey, true);
    }
    state = const AsyncData(true);
    ref.invalidate(walkthroughCompleteProvider);
  }

  Future<void> reset() async {
    final uid = _currentUid();
    if (uid != null) {
      await _writeFirestore(uid, false);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(kHasSeenWalkthroughKey);
    }
    state = const AsyncData(false);
    ref.invalidate(walkthroughCompleteProvider);
  }
}

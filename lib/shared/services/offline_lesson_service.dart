// Offline-aware lesson service — saves lessons to Firestore when online,
// falls back to local Hive storage when offline, and queues for sync.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/services/connectivity_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/services/sync_service.dart';
import 'package:flight_path/shared/models/lesson.dart';

/// Wraps [FirestoreService] lesson operations with offline fallback.
///
/// When the device is online, writes go directly to Firestore. When offline,
/// the lesson is saved locally via [SyncService] and will be synced when
/// connectivity returns.
class OfflineLessonService {
  final FirestoreService _firestore;
  final SyncService _syncService;
  final ConnectivityService _connectivity;

  OfflineLessonService({
    required FirestoreService firestore,
    required SyncService syncService,
    required ConnectivityService connectivity,
  })  : _firestore = firestore,
        _syncService = syncService,
        _connectivity = connectivity;

  /// Creates a lesson. If online, writes to Firestore directly and returns
  /// the Firestore document ID. If offline, saves locally and returns a
  /// temporary local ID.
  Future<String> createLesson(String uid, Lesson lesson) async {
    final isOnline = await _connectivity.checkConnectivity();

    if (isOnline) {
      try {
        return await _firestore.createLesson(uid, lesson);
      } catch (e) {
        // Network error despite connectivity check — fall through to offline.
        debugPrint(
            'OfflineLessonService: Firestore write failed, saving locally: $e');
      }
    }

    // Offline or Firestore error — save locally.
    final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final data = lesson.toFirestore();
    data['pending_sync'] = true;
    data['_uid'] = uid; // Needed to reconstruct the subcollection path on sync.

    // Convert Timestamps to ISO strings for JSON serialisation.
    _convertTimestampsToStrings(data);

    await _syncService.savePendingLesson(localId, data);
    return localId;
  }

  /// Updates a lesson. If offline, queues the update for later sync.
  Future<void> updateLesson(
    String uid,
    String lessonId,
    Map<String, dynamic> data,
  ) async {
    final isOnline = await _connectivity.checkConnectivity();

    if (isOnline) {
      try {
        await _firestore.updateLesson(uid, lessonId, data);
        return;
      } catch (e) {
        debugPrint('OfflineLessonService: update failed, queueing: $e');
      }
    }

    // Queue for later sync.
    final queueData = Map<String, dynamic>.from(data);
    queueData['_uid'] = uid;
    queueData['_lesson_id'] = lessonId;
    _convertTimestampsToStrings(queueData);

    await _syncService.enqueue(SyncQueueEntry(
      id: 'update_${lessonId}_${DateTime.now().millisecondsSinceEpoch}',
      type: SyncOperationType.updateLesson,
      data: queueData,
      createdAt: DateTime.now(),
    ));
  }

  /// Converts Firestore Timestamp values to ISO 8601 strings for JSON storage.
  void _convertTimestampsToStrings(Map<String, dynamic> data) {
    for (final key in data.keys.toList()) {
      final value = data[key];
      if (value is DateTime) {
        data[key] = value.toIso8601String();
      }
      // Handle cloud_firestore Timestamp objects.
      if (value is Timestamp) {
        data[key] = value.toDate().toIso8601String();
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

final offlineLessonServiceProvider = Provider<OfflineLessonService>((ref) {
  return OfflineLessonService(
    firestore: ref.watch(firestoreServiceProvider),
    syncService: ref.watch(syncServiceProvider),
    connectivity: ref.watch(connectivityServiceProvider),
  );
});

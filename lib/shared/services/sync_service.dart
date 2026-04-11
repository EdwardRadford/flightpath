// Offline sync service — queues Firestore writes in Hive when offline and
// processes them when connectivity returns.
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'connectivity_service.dart';

// ---------------------------------------------------------------------------
// Sync queue entry
// ---------------------------------------------------------------------------

/// The type of Firestore operation to replay.
enum SyncOperationType { createLesson, updateLesson, upsertUserExercise }

/// A single queued Firestore write.
class SyncQueueEntry {
  final String id;
  final SyncOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;

  SyncQueueEntry({
    required this.id,
    required this.type,
    required this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'data': data,
        'created_at': createdAt.toIso8601String(),
      };

  factory SyncQueueEntry.fromJson(Map<String, dynamic> json) {
    return SyncQueueEntry(
      id: json['id'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => SyncOperationType.createLesson,
      ),
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Sync service
// ---------------------------------------------------------------------------

/// Manages an offline write queue backed by Hive.
///
/// When the device is offline, callers add entries via [enqueue]. When
/// connectivity returns, [processQueue] replays them against Firestore in
/// order. The queue is persisted so pending writes survive app restarts.
class SyncService {
  static const String _boxName = 'offlineWriteQueue';
  static const String _pendingLessonsBoxName = 'offlineLessonDrafts';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  // ---------------------------------------------------------------------------
  // Hive boxes — opened by HiveService.init() in main() before runApp.
  // ---------------------------------------------------------------------------

  Box<String> get _box => Hive.box<String>(_boxName);
  Box<String> get _pendingLessonsBox => Hive.box<String>(_pendingLessonsBoxName);

  /// Starts listening for connectivity changes. When the device comes back
  /// online, automatically processes the queue.
  void startListening(ConnectivityService connectivity) {
    _connectivitySub?.cancel();
    _connectivitySub = connectivity.onConnectivityChanged.listen((online) {
      if (online) {
        processQueue();
      }
    });
  }

  void dispose() {
    _connectivitySub?.cancel();
  }

  // ---------------------------------------------------------------------------
  // Queue operations
  // ---------------------------------------------------------------------------

  /// Adds a write operation to the offline queue.
  Future<void> enqueue(SyncQueueEntry entry) async {
    await _box.put(entry.id, jsonEncode(entry.toJson()));
  }

  /// Number of pending sync operations.
  int get pendingCount => _box.length;

  /// Replays all queued writes against Firestore, removing each entry on
  /// success. Stops on the first failure so ordering is preserved.
  Future<void> processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      await _processQueueInternal();
    } finally {
      _isProcessing = false;
    }
  }

  Future<void> _processQueueInternal() async {
    final keys = _box.keys.toList();
    for (final key in keys) {
      final raw = _box.get(key);
      if (raw == null) continue;

      // Parse the entry — if this fails the data is corrupt and should be
      // removed so it doesn't block the rest of the queue.
      SyncQueueEntry entry;
      try {
        entry = SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SyncService: corrupt entry $key — skipping: $e');
        }
        await _box.delete(key);
        continue;
      }

      // Replay against Firestore — a failure here is likely a network/server
      // error, so stop and retry on the next connectivity change.
      try {
        await _replayEntry(entry);
        await _box.delete(key);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('SyncService: failed to process entry $key: $e');
        }
        break;
      }
    }

    // Also sync any pending lessons saved offline.
    await _syncPendingLessons();
  }

  /// Validates that queued data has not been tampered with.
  /// Returns false if required fields are missing or malformed.
  bool _validateQueueEntry(SyncQueueEntry entry) {
    final data = entry.data;
    switch (entry.type) {
      case SyncOperationType.createLesson:
        // Must have _uid and status.
        if (data['_uid'] is! String || (data['_uid'] as String).isEmpty) {
          return false;
        }
        if (data['status'] is! String) return false;
        return true;
      case SyncOperationType.updateLesson:
        if (data['_uid'] is! String || (data['_uid'] as String).isEmpty) {
          return false;
        }
        if (data['_lesson_id'] is! String ||
            (data['_lesson_id'] as String).isEmpty) {
          return false;
        }
        return true;
      case SyncOperationType.upsertUserExercise:
        if (data['_uid'] is! String || (data['_uid'] as String).isEmpty) {
          return false;
        }
        if (data['_doc_id'] is! String ||
            (data['_doc_id'] as String).isEmpty) {
          return false;
        }
        return true;
    }
  }

  Future<void> _replayEntry(SyncQueueEntry entry) async {
    // Validate entry before replaying to prevent tampered data from syncing.
    if (!_validateQueueEntry(entry)) {
      if (kDebugMode) {
        debugPrint(
            'SyncService: skipping invalid queue entry ${entry.id}');
      }
      return;
    }

    switch (entry.type) {
      case SyncOperationType.createLesson:
        final uid = entry.data['_uid'] as String;
        final data = Map<String, dynamic>.from(entry.data)
          ..remove('_uid');
        // Convert date strings back to Timestamps for Firestore.
        _restoreTimestamps(data);
        // Write to new subcollection path: users/{uid}/lessons
        await _db
            .collection('users')
            .doc(uid)
            .collection('lessons')
            .add(data);
        break;

      case SyncOperationType.updateLesson:
        final uid = entry.data['_uid'] as String;
        final lessonId = entry.data['_lesson_id'] as String;
        final data = Map<String, dynamic>.from(entry.data)
          ..remove('_uid')
          ..remove('_lesson_id');
        _restoreTimestamps(data);
        // Write to new subcollection path: users/{uid}/lessons/{lessonId}
        await _db
            .collection('users')
            .doc(uid)
            .collection('lessons')
            .doc(lessonId)
            .update(data);
        break;

      case SyncOperationType.upsertUserExercise:
        final uid = entry.data['_uid'] as String;
        final docId = entry.data['_doc_id'] as String;
        final data = Map<String, dynamic>.from(entry.data)
          ..remove('_uid')
          ..remove('_doc_id');
        _restoreTimestamps(data);
        // Write to new subcollection path: users/{uid}/exercises/{docId}
        await _db
            .collection('users')
            .doc(uid)
            .collection('exercises')
            .doc(docId)
            .set(data, SetOptions(merge: true));
        break;
    }
  }

  /// Converts ISO 8601 date strings back to Firestore Timestamps.
  /// Handles nested maps for fields like scheduled_date, lesson_date, etc.
  void _restoreTimestamps(Map<String, dynamic> data) {
    const dateFields = [
      'scheduled_date',
      'lesson_date',
      'created_at',
      'last_attempted',
      'spaced_rep_due',
    ];
    for (final field in dateFields) {
      if (data[field] is String) {
        try {
          data[field] =
              Timestamp.fromDate(DateTime.parse(data[field] as String));
        } catch (_) {
          // Not a valid date string — leave as-is.
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Pending lessons (offline debrief saves)
  // ---------------------------------------------------------------------------

  /// Saves a lesson locally for later sync to Firestore.
  Future<void> savePendingLesson(
    String localId,
    Map<String, dynamic> lessonData,
  ) async {
    await _pendingLessonsBox.put(localId, jsonEncode(lessonData));
  }

  /// Returns the number of lessons waiting to be synced.
  int get pendingLessonCount => _pendingLessonsBox.length;

  /// Returns all pending lessons as maps (for display in logbook).
  List<Map<String, dynamic>> getPendingLessons() {
    return _pendingLessonsBox.values.map((raw) {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }).toList();
  }

  /// Syncs all pending lessons to Firestore.
  Future<void> _syncPendingLessons() async {
    final keys = _pendingLessonsBox.keys.toList();
    for (final key in keys) {
      final raw = _pendingLessonsBox.get(key);
      if (raw == null) continue;

      try {
        final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final uid = data['_uid'] as String? ?? '';
        if (uid.isEmpty) {
          // Cannot determine owner — skip.
          await _pendingLessonsBox.delete(key);
          continue;
        }
        data
          ..remove('_uid')
          ..['pending_sync'] = false; // Mark as synced.
        _restoreTimestamps(data);
        // Write to new subcollection path: users/{uid}/lessons
        await _db
            .collection('users')
            .doc(uid)
            .collection('lessons')
            .add(data);
        await _pendingLessonsBox.delete(key);
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
              'SyncService: failed to sync pending lesson $key: $e');
        }
        break;
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Singleton [SyncService] instance.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService();
  // Start listening for connectivity to auto-process queue.
  final connectivity = ref.watch(connectivityServiceProvider);
  service.startListening(connectivity);
  ref.onDispose(service.dispose);
  return service;
});

/// The number of pending sync operations. UI can watch this to show a badge.
final pendingSyncCountProvider = Provider<int>((ref) {
  final service = ref.watch(syncServiceProvider);
  // Re-evaluate when connectivity changes (queue may have been processed).
  ref.watch(connectivityStreamProvider);
  return service.pendingCount + service.pendingLessonCount;
});

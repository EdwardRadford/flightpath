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
  static const String _boxName = 'sync_queue';
  static const String _pendingLessonsBoxName = 'pending_lessons';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<bool>? _connectivitySub;
  bool _isProcessing = false;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Opens the Hive box for the sync queue. Call once at startup.
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    if (!Hive.isBoxOpen(_pendingLessonsBoxName)) {
      await Hive.openBox<String>(_pendingLessonsBoxName);
    }
  }

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

      try {
        final entry = SyncQueueEntry.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
        await _replayEntry(entry);
        await _box.delete(key);
      } catch (e) {
        // Network still down or Firestore error — stop processing to
        // preserve ordering. Will retry on next connectivity change.
        if (kDebugMode) debugPrint('SyncService: failed to process entry $key: $e');
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
        // Must have user_id and status.
        if (data['user_id'] is! String || (data['user_id'] as String).isEmpty) return false;
        if (data['status'] is! String) return false;
        return true;
      case SyncOperationType.updateLesson:
        if (data['_lesson_id'] is! String || (data['_lesson_id'] as String).isEmpty) return false;
        return true;
      case SyncOperationType.upsertUserExercise:
        if (data['_doc_id'] is! String || (data['_doc_id'] as String).isEmpty) return false;
        if (data['user_id'] is! String || (data['user_id'] as String).isEmpty) return false;
        return true;
    }
  }

  Future<void> _replayEntry(SyncQueueEntry entry) async {
    // Validate entry before replaying to prevent tampered data from syncing.
    if (!_validateQueueEntry(entry)) {
      if (kDebugMode) debugPrint('SyncService: skipping invalid queue entry ${entry.id}');
      return;
    }

    switch (entry.type) {
      case SyncOperationType.createLesson:
        // The 'id' field in data is the local temp ID — Firestore will assign
        // a real one. We store under the exercise key to avoid duplicates.
        final data = Map<String, dynamic>.from(entry.data);
        // Convert date strings back to Timestamps for Firestore.
        _restoreTimestamps(data);
        await _db.collection('lessons').add(data);
        break;

      case SyncOperationType.updateLesson:
        final lessonId = entry.data['_lesson_id'] as String;
        final data = Map<String, dynamic>.from(entry.data)
          ..remove('_lesson_id');
        _restoreTimestamps(data);
        await _db.collection('lessons').doc(lessonId).update(data);
        break;

      case SyncOperationType.upsertUserExercise:
        final docId = entry.data['_doc_id'] as String;
        final data = Map<String, dynamic>.from(entry.data)..remove('_doc_id');
        _restoreTimestamps(data);
        await _db
            .collection('user_exercises')
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
          data[field] = Timestamp.fromDate(DateTime.parse(data[field] as String));
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
        data['pending_sync'] = false; // Mark as synced.
        _restoreTimestamps(data);
        await _db.collection('lessons').add(data);
        await _pendingLessonsBox.delete(key);
      } catch (e) {
        if (kDebugMode) debugPrint('SyncService: failed to sync pending lesson $key: $e');
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

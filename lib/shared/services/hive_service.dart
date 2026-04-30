// Local cache service for exercise content, quiz questions, and offline
// lessons using Hive.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Manages local caching of exercise content, quiz questions, flashcards, and
/// offline lessons using Hive.
///
/// [init] must be called once at app startup. After that, any number of
/// HiveService instances can be created — they all reference the same
/// already-opened Hive boxes via [Hive.box].
///
/// Five Hive boxes:
///   - exerciseContent   — keyed by exercise ID
///   - quizQuestions     — keyed by exercise ID
///   - flashcards        — keyed by exercise ID
///   - offlineWriteQueue — keyed by queue entry ID
///   - offlineLessonDrafts — keyed by local lesson ID
class HiveService {
  static const String _contentBoxName = 'exerciseContent';
  static const String _versionsBoxName = 'exercise_content_versions';
  static const String _quizBoxName = 'quizQuestions';
  static const String _flashcardsBoxName = 'flashcards';
  static const String _cacheTimestampsBoxName = 'cache_timestamps';
  static const String _offlineWriteQueueBoxName = 'offlineWriteQueue';
  static const String _offlineLessonDraftsBoxName = 'offlineLessonDrafts';
  static const String _askAiHistoryBoxName = 'ask_ai_history';

  // ---------------------------------------------------------------------------
  // Initialisation (call once in main.dart before runApp)
  // ---------------------------------------------------------------------------

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isBoxOpen(_contentBoxName)) {
      await Hive.openBox<Map>(_contentBoxName);
    }
    if (!Hive.isBoxOpen(_versionsBoxName)) {
      await Hive.openBox<int>(_versionsBoxName);
    }
    if (!Hive.isBoxOpen(_quizBoxName)) {
      await Hive.openBox<String>(_quizBoxName);
    }
    if (!Hive.isBoxOpen(_flashcardsBoxName)) {
      await Hive.openBox<String>(_flashcardsBoxName);
    }
    if (!Hive.isBoxOpen(_cacheTimestampsBoxName)) {
      await Hive.openBox<String>(_cacheTimestampsBoxName);
    }
    if (!Hive.isBoxOpen(_offlineWriteQueueBoxName)) {
      await Hive.openBox<String>(_offlineWriteQueueBoxName);
    }
    if (!Hive.isBoxOpen(_offlineLessonDraftsBoxName)) {
      await Hive.openBox<String>(_offlineLessonDraftsBoxName);
    }
    if (!Hive.isBoxOpen(_askAiHistoryBoxName)) {
      await Hive.openBox<String>(_askAiHistoryBoxName);
    }
  }

  // Accessors — always safe after init() has been awaited.
  Box<Map> get _contentBox => Hive.box<Map>(_contentBoxName);
  Box<int> get _versionsBox => Hive.box<int>(_versionsBoxName);
  Box<String> get _quizBox => Hive.box<String>(_quizBoxName);
  Box<String> get _flashcardsBox => Hive.box<String>(_flashcardsBoxName);
  Box<String> get _timestampsBox => Hive.box<String>(_cacheTimestampsBoxName);

  /// The offline write queue box (keyed by queue entry ID).
  Box<String> get offlineWriteQueueBox =>
      Hive.box<String>(_offlineWriteQueueBoxName);

  /// The offline lesson drafts box (keyed by local lesson ID).
  Box<String> get offlineLessonDraftsBox =>
      Hive.box<String>(_offlineLessonDraftsBoxName);

  /// The Ask AI chat history box. Stores a single JSON-encoded list of
  /// `{role, content, timestamp}` records under the key `messages` so the
  /// chat survives navigation away from the screen. Per-user separation is
  /// not required — the Hive directory is wiped on sign-out elsewhere — but
  /// the key is namespaced for clarity.
  Box<String> get askAiHistoryBox =>
      Hive.box<String>(_askAiHistoryBoxName);

  // ---------------------------------------------------------------------------
  // Cache operations
  // ---------------------------------------------------------------------------

  /// Stores [data] and its [version] in the local cache under [key].
  Future<void> cacheExerciseContent(
    String key,
    Map<String, dynamic> data,
    int version,
  ) async {
    await _contentBox.put(key, data);
    await _versionsBox.put(key, version);
  }

  /// Returns cached content for [key] if the stored version matches [currentVersion].
  Future<Map<String, dynamic>?> getCachedExerciseContent(
    String key,
    int currentVersion,
  ) async {
    final cachedVersion = _versionsBox.get(key);
    if (cachedVersion == null || cachedVersion != currentVersion) return null;
    final raw = _contentBox.get(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Returns cached exercise content map for [key] regardless of version.
  /// Returns null if nothing is cached for this key.
  /// Synchronous — Hive boxes are already open in memory.
  Map<String, dynamic>? getCachedExerciseContentAny(String key) {
    final raw = _contentBox.get(key);
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }

  /// Removes all cached exercise content and version records.
  Future<void> clearExerciseCache() async {
    await _contentBox.clear();
    await _versionsBox.clear();
    await _quizBox.clear();
    await _flashcardsBox.clear();
    await _timestampsBox.clear();
  }

  // ---------------------------------------------------------------------------
  // Quiz question caching
  // ---------------------------------------------------------------------------

  /// Caches quiz questions for a given exercise key as JSON.
  Future<void> cacheQuizQuestions(
    String key,
    List<Map<String, dynamic>> questions,
  ) async {
    await _quizBox.put(key, jsonEncode(questions));
    await _setCacheTimestamp('quiz_$key');
  }

  /// Returns cached quiz questions for [key], or null if not cached.
  List<Map<String, dynamic>>? getCachedQuizQuestions(String key) {
    final raw = _quizBox.get(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Flashcard caching
  // ---------------------------------------------------------------------------

  /// Caches flashcards for a given exercise key as JSON.
  Future<void> cacheFlashcards(
    String key,
    List<Map<String, dynamic>> cards,
  ) async {
    await _flashcardsBox.put(key, jsonEncode(cards));
    await _setCacheTimestamp('flashcards_$key');
  }

  /// Returns cached flashcards for [key], or null if not cached.
  List<Map<String, dynamic>>? getCachedFlashcards(String key) {
    final raw = _flashcardsBox.get(key);
    if (raw == null) return null;
    final decoded = jsonDecode(raw) as List;
    return decoded
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Cache timestamps — "Last updated: X ago"
  // ---------------------------------------------------------------------------

  /// Records when data for [key] was last fetched from Firestore.
  Future<void> _setCacheTimestamp(String key) async {
    await _timestampsBox.put(key, DateTime.now().toIso8601String());
  }

  /// Records a cache timestamp for exercise content.
  Future<void> setContentCacheTimestamp(String key) async {
    await _setCacheTimestamp('content_$key');
  }

  /// Returns the DateTime when [key] was last cached, or null.
  DateTime? getCacheTimestamp(String key) {
    final raw = _timestampsBox.get(key);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Returns a human-readable "last updated" string for exercise content.
  String? getContentLastUpdated(String key) {
    final ts = getCacheTimestamp('content_$key');
    return ts != null ? _formatTimeAgo(ts) : null;
  }

  /// Returns a human-readable "last updated" string for quiz questions.
  String? getQuizLastUpdated(String key) {
    final ts = getCacheTimestamp('quiz_$key');
    return ts != null ? _formatTimeAgo(ts) : null;
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) {
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    }
    return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides a singleton [HiveService] instance.
final hiveServiceProvider = Provider<HiveService>(
  (ref) => HiveService(),
);

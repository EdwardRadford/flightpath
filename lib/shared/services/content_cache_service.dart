// Offline content cache service — stale-while-revalidate pattern for exercise
// content and quiz questions. Returns cached data immediately, then refreshes
// from Firestore in the background.
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/flashcard.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/services/connectivity_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/services/hive_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

/// Manages offline caching of exercise content and quiz questions.
///
/// Strategy: stale-while-revalidate.
/// 1. Return cached data immediately if available.
/// 2. Fetch fresh data from Firestore in the background.
/// 3. Update cache on successful fetch.
class ContentCacheService {
  final HiveService _hive;
  final FirestoreService _firestore;
  final bool _isOnline;

  ContentCacheService({
    required HiveService hive,
    required FirestoreService firestore,
    required bool isOnline,
  })  : _hive = hive,
        _firestore = firestore,
        _isOnline = isOnline;

  // ---------------------------------------------------------------------------
  // Exercise content — stale-while-revalidate
  // ---------------------------------------------------------------------------

  /// Returns exercise content, preferring cache. If online, triggers a
  /// background refresh. Returns null only if both cache and Firestore miss.
  Future<ExerciseContent?> getExerciseContent(
    String exerciseId, {
    String? subExerciseId,
  }) async {
    final cacheKey = subExerciseId != null
        ? '${exerciseId}_$subExerciseId'
        : exerciseId;

    // Try cache first.
    final cachedMap = _hive.getCachedExerciseContentAny(cacheKey);
    ExerciseContent? cached;
    if (cachedMap != null) {
      cached = ExerciseContent.fromMap(cacheKey, cachedMap);
    }

    // If online, refresh in background.
    if (_isOnline) {
      _refreshExerciseContent(exerciseId, subExerciseId, cacheKey);
    }

    // If we have cache, return it immediately.
    if (cached != null) return cached;

    // No cache — must fetch from Firestore (blocks until result).
    if (!_isOnline) return null;

    final fresh = await _firestore.getExerciseContent(
      exerciseId,
      subExerciseId: subExerciseId,
    );
    if (fresh != null) {
      await _hive.cacheExerciseContent(
          cacheKey, fresh.toMap(), fresh.contentVersion);
      await _hive.setContentCacheTimestamp(cacheKey);
    }
    return fresh;
  }

  /// Background refresh — fetches from Firestore and updates cache.
  Future<void> _refreshExerciseContent(
    String exerciseId,
    String? subExerciseId,
    String cacheKey,
  ) async {
    try {
      final fresh = await _firestore.getExerciseContent(
        exerciseId,
        subExerciseId: subExerciseId,
      );
      if (fresh != null) {
        await _hive.cacheExerciseContent(
            cacheKey, fresh.toMap(), fresh.contentVersion);
        await _hive.setContentCacheTimestamp(cacheKey);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ContentCacheService: background refresh failed for '
            '$cacheKey: $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'ContentCacheService: exercise content refresh failed for $cacheKey',
        fatal: false,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Quiz questions — cache with background refresh
  // ---------------------------------------------------------------------------

  /// Returns quiz questions for an exercise, preferring cache.
  /// If online, triggers a background refresh.
  Future<List<QuizQuestion>> getQuizQuestions(
    String exerciseId, {
    String? subExerciseId,
  }) async {
    final cacheKey = subExerciseId != null
        ? '${exerciseId}_$subExerciseId'
        : exerciseId;

    // Try cache first.
    final cachedJson = _hive.getCachedQuizQuestions(cacheKey);
    List<QuizQuestion>? cached;
    if (cachedJson != null && cachedJson.isNotEmpty) {
      cached = cachedJson
          .map((map) => QuizQuestion.fromMap(cacheKey, map))
          .toList();
    }

    // If online, refresh in background.
    if (_isOnline) {
      _refreshQuizQuestions(exerciseId, subExerciseId, cacheKey);
    }

    if (cached != null && cached.isNotEmpty) return cached;

    // No cache — fetch from Firestore.
    if (!_isOnline) return [];

    final fresh = await _firestore.getQuizQuestions(
      exerciseId,
      subExerciseId: subExerciseId,
    );
    if (fresh.isNotEmpty) {
      await _cacheQuizQuestions(cacheKey, fresh);
    }
    return fresh;
  }

  Future<void> _refreshQuizQuestions(
    String exerciseId,
    String? subExerciseId,
    String cacheKey,
  ) async {
    try {
      final fresh = await _firestore.getQuizQuestions(
        exerciseId,
        subExerciseId: subExerciseId,
      );
      if (fresh.isNotEmpty) {
        await _cacheQuizQuestions(cacheKey, fresh);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ContentCacheService: quiz refresh failed for '
            '$cacheKey: $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'ContentCacheService: quiz refresh failed for $cacheKey',
        fatal: false,
      );
    }
  }

  Future<void> _cacheQuizQuestions(
    String cacheKey,
    List<QuizQuestion> questions,
  ) async {
    final maps = questions.map((q) => q.toMap()).toList();
    await _hive.cacheQuizQuestions(cacheKey, maps);
  }

  // ---------------------------------------------------------------------------
  // Flashcards — cache with background refresh
  // ---------------------------------------------------------------------------

  /// Returns flashcards for an exercise, preferring cache.
  /// If online, triggers a background refresh.
  Future<List<Flashcard>> getFlashcards(String exerciseId) async {
    final cacheKey = exerciseId;

    // Try cache first.
    final cachedJson = _hive.getCachedFlashcards(cacheKey);
    List<Flashcard>? cached;
    if (cachedJson != null && cachedJson.isNotEmpty) {
      cached = cachedJson
          .map((map) => Flashcard.fromMap(cacheKey, map))
          .toList();
    }

    // If online, refresh in background.
    if (_isOnline) {
      _refreshFlashcards(exerciseId, cacheKey);
    }

    if (cached != null && cached.isNotEmpty) return cached;

    // No cache — fetch from Firestore.
    if (!_isOnline) return [];

    final fresh = await _firestore.getFlashcards(exerciseId);
    if (fresh.isNotEmpty) {
      await _cacheFlashcards(cacheKey, fresh);
    }
    return fresh;
  }

  Future<void> _refreshFlashcards(
    String exerciseId,
    String cacheKey,
  ) async {
    try {
      final fresh = await _firestore.getFlashcards(exerciseId);
      if (fresh.isNotEmpty) {
        await _cacheFlashcards(cacheKey, fresh);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ContentCacheService: flashcard refresh failed for '
            '$cacheKey: $e');
      }
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'ContentCacheService: flashcard refresh failed for $cacheKey',
        fatal: false,
      );
    }
  }

  Future<void> _cacheFlashcards(
    String cacheKey,
    List<Flashcard> cards,
  ) async {
    final maps = cards.map((c) => c.toMap()).toList();
    await _hive.cacheFlashcards(cacheKey, maps);
  }

  // ---------------------------------------------------------------------------
  // Prefetch all content
  // ---------------------------------------------------------------------------

  /// Downloads and caches all exercise content and quiz questions.
  /// Call this when the user has connectivity (e.g. on app launch or from
  /// a settings "Download all content" button).
  ///
  /// Returns the number of exercises successfully cached.
  Future<int> prefetchAllContent() async {
    if (!_isOnline) return 0;

    int cached = 0;

    for (final compositeId in AppConstants.allExerciseIds) {
      final (exerciseId, subExerciseId) = parseExerciseId(compositeId);
      final cacheKey = subExerciseId != null
          ? '${exerciseId}_$subExerciseId'
          : exerciseId;

      try {
        // Fetch and cache exercise content.
        final content = await _firestore.getExerciseContent(
          exerciseId,
          subExerciseId: subExerciseId,
        );
        if (content != null) {
          await _hive.cacheExerciseContent(
              cacheKey, content.toMap(), content.contentVersion);
          await _hive.setContentCacheTimestamp(cacheKey);
        }

        // Fetch and cache quiz questions.
        final questions = await _firestore.getQuizQuestions(
          exerciseId,
          subExerciseId: subExerciseId,
        );
        if (questions.isNotEmpty) {
          await _cacheQuizQuestions(cacheKey, questions);
        }

        // Fetch and cache flashcards (keyed by composite ID, e.g. 'ex_10_10a').
        final cards = await _firestore.getFlashcards(cacheKey);
        if (cards.isNotEmpty) {
          await _cacheFlashcards(cacheKey, cards);
        }

        cached++;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('ContentCacheService: prefetch failed for '
              '$compositeId: $e');
        }
        // Continue with next exercise — don't let one failure stop the rest.
        FirebaseCrashlytics.instance.recordError(
          e, st,
          reason: 'ContentCacheService: prefetch failed for $compositeId',
          fatal: false,
        );
      }
    }

    return cached;
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// [ContentCacheService] instance — rebuilds when connectivity state changes.
final contentCacheServiceProvider = Provider<ContentCacheService>((ref) {
  return ContentCacheService(
    hive: ref.watch(hiveServiceProvider),
    firestore: ref.watch(firestoreServiceProvider),
    isOnline: ref.watch(isOnlineProvider),
  );
});

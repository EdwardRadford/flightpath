// Exercise data providers — Firestore/Hive service singletons, user exercise
// streams, cached exercise content, and quiz questions.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/services/firestore_service.dart';
import 'package:flight_path/core/services/hive_service.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

// ---------------------------------------------------------------------------
// Service providers
// ---------------------------------------------------------------------------

/// Provides a singleton [FirestoreService] instance.
final firestoreServiceProvider = Provider<FirestoreService>(
  (ref) => FirestoreService(),
);

/// Provides a singleton [HiveService] instance.
/// Note: [HiveService.init] must have been awaited before this provider is
/// first read (typically done in main.dart before runApp).
final hiveServiceProvider = Provider<HiveService>(
  (ref) => HiveService(),
);

// ---------------------------------------------------------------------------
// User exercises
// ---------------------------------------------------------------------------

/// Streams all [UserExercise] records for the currently authenticated user.
///
/// Emits an empty list while the user is unauthenticated.
final userExercisesProvider = StreamProvider<List<UserExercise>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) {
    return const Stream.empty();
  }
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.userExercisesStream(uid);
});

// ---------------------------------------------------------------------------
// Exercise content (with Hive cache)
// ---------------------------------------------------------------------------

/// Fetches [ExerciseContent] for the given (exerciseId, subExerciseId?) pair.
///
/// Strategy (cache-first for speed):
/// 1. Check Hive cache — if we have data cached (and main.dart's startup
///    cache invalidation already cleared stale versions), return immediately.
/// 2. On cache miss, fetch from Firestore, cache the result, and return.
///
/// Returns null if no document exists in either cache or Firestore.
final exerciseContentProvider =
    FutureProvider.family<ExerciseContent?, (String, String?)>(
  (ref, args) async {
    final exerciseId = args.$1;
    final subExerciseId = args.$2;

    final firestore = ref.watch(firestoreServiceProvider);
    final hive = ref.watch(hiveServiceProvider);

    // Build the cache key to match Firestore's doc ID convention.
    final cacheKey = subExerciseId != null
        ? '${exerciseId}_$subExerciseId'
        : exerciseId;

    // Try Hive cache first (synchronous — no Firestore read needed).
    // Cache invalidation on version change is handled at startup in main.dart.
    final cachedMap = hive.getCachedExerciseContentAny(cacheKey);
    if (cachedMap != null) {
      return ExerciseContent.fromMap(cacheKey, cachedMap);
    }

    // Cache miss — fetch from Firestore.
    final content = await firestore.getExerciseContent(
      exerciseId,
      subExerciseId: subExerciseId,
    );

    if (content == null) return null;

    // Store in Hive for next time.
    await hive.cacheExerciseContent(
      cacheKey,
      content.toFirestore(),
      content.contentVersion,
    );

    return content;
  },
);

// ---------------------------------------------------------------------------
// Quiz questions
// ---------------------------------------------------------------------------

/// Fetches quiz questions for the given (exerciseId, subExerciseId?) pair.
///
/// Returns up to 10 shuffled [QuizQuestion] objects, ready for display.
final quizQuestionsProvider =
    FutureProvider.family<List<QuizQuestion>, (String, String?)>(
  (ref, args) async {
    final exerciseId = args.$1;
    final subExerciseId = args.$2;

    final firestore = ref.watch(firestoreServiceProvider);
    return firestore.getQuizQuestions(
      exerciseId,
      subExerciseId: subExerciseId,
    );
  },
);

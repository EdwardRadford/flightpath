// Exercise data providers — user exercise streams, cached exercise content, and quiz questions.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/content_cache_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/models/quiz_question.dart';

// ---------------------------------------------------------------------------
// User exercises
// ---------------------------------------------------------------------------

/// Streams all [UserExercise] records for the currently authenticated user.
///
/// Emits an empty list while the user is unauthenticated.
final userExercisesProvider = StreamProvider<List<UserExercise>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.userExercisesStream(uid);
});

// ---------------------------------------------------------------------------
// Exercise content (with Hive cache)
// ---------------------------------------------------------------------------

/// Fetches [ExerciseContent] for the given (exerciseId, subExerciseId?) pair.
///
/// Stale-while-revalidate: returns cached data immediately, then refreshes
/// from Firestore in the background when online. Returns null only if both
/// cache and Firestore miss.
final exerciseContentProvider =
    FutureProvider.family<ExerciseContent?, (String, String?)>(
  (ref, args) async {
    final exerciseId = args.$1;
    final subExerciseId = args.$2;
    final cache = ref.watch(contentCacheServiceProvider);
    return cache.getExerciseContent(
      exerciseId,
      subExerciseId: subExerciseId,
    );
  },
);

// ---------------------------------------------------------------------------
// Quiz questions
// ---------------------------------------------------------------------------

/// Fetches quiz questions for the given (exerciseId, subExerciseId?) pair.
///
/// Uses [ContentCacheService] for offline caching with background refresh.
final quizQuestionsProvider =
    FutureProvider.family<List<QuizQuestion>, (String, String?)>(
  (ref, args) async {
    final exerciseId = args.$1;
    final subExerciseId = args.$2;
    final cache = ref.watch(contentCacheServiceProvider);
    return cache.getQuizQuestions(
      exerciseId,
      subExerciseId: subExerciseId,
    );
  },
);

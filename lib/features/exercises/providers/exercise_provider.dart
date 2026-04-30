// Exercise data providers — user exercise streams, cached exercise content, and quiz questions.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/content_cache_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/models/flashcard.dart';
import 'package:flight_path/shared/models/quiz_question.dart';

// ---------------------------------------------------------------------------
// Exercise write helpers
// ---------------------------------------------------------------------------

/// Saves post-lesson debrief notes and focus for next time.
///
/// No-ops silently if the user is unauthenticated or the exercise record
/// does not yet exist (the caller should ensure it exists after a lesson save).
Future<void> saveDebrief(
  WidgetRef ref,
  String exerciseId,
  String? subExercise,
  String? notes,
  String? focus,
) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return;
  final firestore = ref.read(firestoreServiceProvider);
  final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
    return ue.exerciseId == exerciseId && ue.subExercise == subExercise;
  }).firstOrNull;
  if (existing == null) return;
  final safeNotes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
  final safeFocus = (focus?.trim().isEmpty ?? true) ? null : focus!.trim();
  // Write debrief fields directly so that null values clear existing data.
  await firestore.updateUserExerciseFields(uid, existing.id, {
    'debrief_notes': safeNotes,
    'focus_next_time': safeFocus,
  });
}

/// Saves the instructor notes field for a given exercise.
///
/// No-ops silently if the user is unauthenticated or the exercise record
/// does not yet exist.
Future<void> saveInstructorNotes(
  WidgetRef ref,
  String exerciseId,
  String? subExercise,
  String? notes,
) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return;
  final firestore = ref.read(firestoreServiceProvider);
  final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
    return ue.exerciseId == exerciseId && ue.subExercise == subExercise;
  }).firstOrNull;
  if (existing == null) return;
  final safeNotes = (notes?.trim().isEmpty ?? true) ? null : notes!.trim();
  await firestore.updateUserExerciseFields(uid, existing.id, {
    'instructor_notes': safeNotes,
  });
}

/// Saves the AI-generated debrief text for a given exercise.
Future<void> saveAiDebrief(
  WidgetRef ref,
  String exerciseId,
  String? subExercise,
  String notes,
) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return;
  final firestore = ref.read(firestoreServiceProvider);
  final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
    return ue.exerciseId == exerciseId && ue.subExercise == subExercise;
  }).firstOrNull;
  if (existing == null) return;
  final safe = notes.trim().isEmpty ? null : notes.trim();
  await firestore.updateUserExerciseFields(uid, existing.id, {
    'ai_debrief_notes': safe,
  });
}

/// Sets beforeYouFlyViewed = true for the given exercise.
Future<void> markBeforeYouFlyViewed(
  WidgetRef ref,
  String exerciseId,
  String? subExercise,
) async {
  final uid = ref.read(currentUserIdProvider);
  if (uid == null) return;
  final firestore = ref.read(firestoreServiceProvider);
  final existing = ref.read(userExercisesProvider).valueOrNull?.where((ue) {
    return ue.exerciseId == exerciseId && ue.subExercise == subExercise;
  }).firstOrNull;
  if (existing == null || existing.beforeYouFlyViewed) return;
  await firestore.upsertUserExercise(
    uid,
    existing.copyWith(beforeYouFlyViewed: true),
  );
}

/// Returns the spacedRepDue offset for a given student self-rating (1–5).
Duration spacedRepDueOffsetForRating(int rating) {
  if (rating <= 2) return const Duration(days: 3);
  if (rating == 3) return const Duration(days: 7);
  return const Duration(days: 14);
}

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

// ---------------------------------------------------------------------------
// Flashcards
// ---------------------------------------------------------------------------

/// Fetches flashcards for the given composite exercise ID.
///
/// Uses [ContentCacheService] for offline caching with background refresh.
final flashcardsProvider =
    FutureProvider.family<List<Flashcard>, String>(
  (ref, compositeExerciseId) async {
    final cache = ref.watch(contentCacheServiceProvider);
    return cache.getFlashcards(compositeExerciseId);
  },
);

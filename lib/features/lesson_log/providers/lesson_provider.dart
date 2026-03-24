// Lesson data providers — streams all lessons and filters by exercise.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';

/// Streams every lesson for the current user, ordered newest first.
///
/// Emits an empty list while unauthenticated.
final allLessonsProvider = StreamProvider<List<Lesson>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return const Stream.empty();

  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.userLessonsStream(uid);
});

/// Returns all lessons for the current user that belong to [exerciseId].
///
/// Results are ordered newest first (inherited from [allLessonsProvider]).
/// Returns an empty list while unauthenticated or when the parent stream
/// has not yet emitted.
final lessonsByExerciseProvider =
    FutureProvider.family<List<Lesson>, String>((ref, exerciseId) async {
  final lessonsAsync = ref.watch(allLessonsProvider);

  // Wait for the stream to emit its first value.
  final lessons = await lessonsAsync.when(
    data: (data) async => data,
    loading: () async {
      // Wait for the next value from the underlying stream.
      return ref.read(allLessonsProvider.future);
    },
    error: (err, stack) async => <Lesson>[],
  );

  return lessons
      .where((lesson) => lesson.exerciseId == exerciseId)
      .toList();
});

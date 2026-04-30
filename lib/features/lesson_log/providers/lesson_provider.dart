// Lesson data providers — streams all lessons for the current user.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/lesson.dart';

/// Streams every lesson for the current user, ordered newest first.
///
/// Emits an empty list while unauthenticated.
final allLessonsProvider = StreamProvider<List<Lesson>>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);
  final firestore = ref.watch(firestoreServiceProvider);
  return firestore.userLessonsStream(uid);
});

/// Returns all lessons for the current user that belong to [exerciseId].
final lessonsByExerciseProvider =
    FutureProvider.family<List<Lesson>, String>((ref, exerciseId) async {
  final lessonsAsync = ref.watch(allLessonsProvider);

  final lessons = await lessonsAsync.when(
    data: (data) async => data,
    loading: () async => ref.read(allLessonsProvider.future),
    error: (_, __) async => <Lesson>[],
  );

  return lessons.where((l) => l.exerciseId == exerciseId).toList();
});

/// Most recent non-empty instructor name across all logged lessons, or null
/// when no lesson has one. Used by the lesson form to pre-fill the instructor
/// field on new entries.
final lastInstructorNameProvider = Provider<String?>((ref) {
  final lessons = ref.watch(allLessonsProvider).valueOrNull;
  if (lessons == null || lessons.isEmpty) return null;
  for (final lesson in lessons) {
    if (lesson.instructorName.trim().isNotEmpty) return lesson.instructorName;
  }
  return null;
});

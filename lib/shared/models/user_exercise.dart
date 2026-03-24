// Per-user per-exercise progress model — maps to the Firestore
// `user_exercises` collection.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks a student's progress through an exercise.
enum ExerciseStatus { notStarted, inProgress, complete }

/// Stores progress, best rating, rating history, and spaced-repetition
/// schedule for a single exercise or sub-exercise.
class UserExercise {
  final String id;
  final String userId;
  final String exerciseId;
  final String? subExercise;
  final int exerciseNumber;
  final ExerciseStatus status;
  final int? bestRating;
  final int timesAttempted;
  final List<int> ratingHistory;
  final DateTime? lastAttempted;
  final bool videoWatched;
  final bool briefViewed;
  final bool flashcardsCompleted;
  final bool weatherChecked;
  final bool quizPassed;
  final bool visualisationViewed;
  final DateTime? spacedRepDue;

  const UserExercise({
    required this.id,
    required this.userId,
    required this.exerciseId,
    this.subExercise,
    required this.exerciseNumber,
    required this.status,
    this.bestRating,
    required this.timesAttempted,
    required this.ratingHistory,
    this.lastAttempted,
    required this.videoWatched,
    required this.briefViewed,
    required this.flashcardsCompleted,
    required this.weatherChecked,
    required this.quizPassed,
    required this.visualisationViewed,
    this.spacedRepDue,
  });

  /// Constructs a [UserExercise] from a Firestore document snapshot.
  factory UserExercise.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserExercise(
      id: doc.id,
      userId: data['user_id'] ?? '',
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      exerciseNumber: data['exercise_number'] ?? 0,
      status: _parseStatus(data['status']),
      bestRating: data['best_rating'],
      timesAttempted: data['times_attempted'] ?? 0,
      ratingHistory: List<int>.from(data['rating_history'] ?? []),
      lastAttempted: (data['last_attempted'] as Timestamp?)?.toDate(),
      videoWatched: data['video_watched'] ?? false,
      briefViewed: data['brief_viewed'] ?? false,
      flashcardsCompleted: data['flashcards_completed'] ?? false,
      weatherChecked: data['weather_checked'] ?? false,
      quizPassed: data['quiz_passed'] ?? false,
      visualisationViewed: data['visualisation_viewed'] ?? false,
      spacedRepDue: (data['spaced_rep_due'] as Timestamp?)?.toDate(),
    );
  }

  static ExerciseStatus _parseStatus(String? value) {
    switch (value) {
      case 'in_progress': return ExerciseStatus.inProgress;
      case 'complete': return ExerciseStatus.complete;
      default: return ExerciseStatus.notStarted;
    }
  }

  /// Serialises this record to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'exercise_id': exerciseId,
    if (subExercise != null) 'sub_exercise': subExercise,
    'exercise_number': exerciseNumber,
    'status': status == ExerciseStatus.notStarted
        ? 'not_started'
        : status == ExerciseStatus.inProgress
            ? 'in_progress'
            : 'complete',
    if (bestRating != null) 'best_rating': bestRating,
    'times_attempted': timesAttempted,
    'rating_history': ratingHistory,
    if (lastAttempted != null) 'last_attempted': Timestamp.fromDate(lastAttempted!),
    'video_watched': videoWatched,
    'brief_viewed': briefViewed,
    'flashcards_completed': flashcardsCompleted,
    'weather_checked': weatherChecked,
    'quiz_passed': quizPassed,
    'visualisation_viewed': visualisationViewed,
    if (spacedRepDue != null) 'spaced_rep_due': Timestamp.fromDate(spacedRepDue!),
  };

  /// Returns a copy with the given fields replaced.
  UserExercise copyWith({
    String? id,
    String? userId,
    String? exerciseId,
    String? subExercise,
    int? exerciseNumber,
    ExerciseStatus? status,
    int? bestRating,
    int? timesAttempted,
    List<int>? ratingHistory,
    DateTime? lastAttempted,
    bool? videoWatched,
    bool? briefViewed,
    bool? flashcardsCompleted,
    bool? weatherChecked,
    bool? quizPassed,
    bool? visualisationViewed,
    DateTime? spacedRepDue,
  }) {
    return UserExercise(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      exerciseId: exerciseId ?? this.exerciseId,
      subExercise: subExercise ?? this.subExercise,
      exerciseNumber: exerciseNumber ?? this.exerciseNumber,
      status: status ?? this.status,
      bestRating: bestRating ?? this.bestRating,
      timesAttempted: timesAttempted ?? this.timesAttempted,
      ratingHistory: ratingHistory ?? this.ratingHistory,
      lastAttempted: lastAttempted ?? this.lastAttempted,
      videoWatched: videoWatched ?? this.videoWatched,
      briefViewed: briefViewed ?? this.briefViewed,
      flashcardsCompleted: flashcardsCompleted ?? this.flashcardsCompleted,
      weatherChecked: weatherChecked ?? this.weatherChecked,
      quizPassed: quizPassed ?? this.quizPassed,
      visualisationViewed: visualisationViewed ?? this.visualisationViewed,
      spacedRepDue: spacedRepDue ?? this.spacedRepDue,
    );
  }
}

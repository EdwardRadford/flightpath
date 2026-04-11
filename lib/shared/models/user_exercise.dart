// Per-user per-exercise progress model — maps to `users/{uid}/exercises/{exerciseId}`.
// userId is NOT stored on the model — ownership is expressed by the path.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks a student's progress through an exercise.
enum ExerciseStatus {
  notStarted,
  inProgress,
  completedUnsatisfactory,
  completedSatisfactory,
}

extension ExerciseStatusX on ExerciseStatus {
  /// Human-readable label for display.
  String get label => switch (this) {
    ExerciseStatus.notStarted => 'Not Started',
    ExerciseStatus.inProgress => 'Started',
    ExerciseStatus.completedUnsatisfactory => 'Done — Needs Work',
    ExerciseStatus.completedSatisfactory => 'Done — Satisfactory',
  };

  /// Whether this status counts as "completed" (either satisfactory or not).
  bool get isCompleted =>
      this == ExerciseStatus.completedUnsatisfactory ||
      this == ExerciseStatus.completedSatisfactory;
}

/// Stores progress, best rating, rating history, and spaced-repetition
/// schedule for a single exercise or sub-exercise.
class UserExercise {
  final String id;
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
  final bool quizAttempted;
  final bool visualisationViewed;
  final DateTime? spacedRepDue;

  /// Per-question mastery: questionId → consecutive correct count.
  /// A count ≥ 2 marks a question as "mastered" and deprioritises it.
  final Map<String, int> quizMastery;

  /// Indices of pre-flight checklist items the student has completed.
  final List<int> checklistCompleted;

  const UserExercise({
    required this.id,
    required this.exerciseId,
    this.subExercise,
    required this.exerciseNumber,
    required this.status,
    this.bestRating,
    required this.timesAttempted,
    required this.ratingHistory,
    this.lastAttempted,
    this.videoWatched = false,
    this.briefViewed = false,
    this.flashcardsCompleted = false,
    this.weatherChecked = false,
    this.quizPassed = false,
    this.quizAttempted = false,
    this.visualisationViewed = false,
    this.spacedRepDue,
    this.quizMastery = const {},
    this.checklistCompleted = const [],
  });

  // ── Activity status getters ───────────────────────────────────────────

  /// Quiz status: 'Not Started', 'Unsatisfactory', or 'Satisfactory'.
  String get quizStatus {
    if (!quizAttempted) return 'Not Started';
    return quizPassed ? 'Satisfactory' : 'Unsatisfactory';
  }

  /// Brief status: 'Not Viewed' or 'Viewed'.
  String get briefStatus => briefViewed ? 'Viewed' : 'Not Viewed';

  /// Visualisation/video status: 'Not Watched' or 'Watched'.
  String get visualisationStatus =>
      visualisationViewed ? 'Watched' : 'Not Watched';

  /// Flashcards status: 'Not Started' or 'Completed'.
  String get flashcardsStatus =>
      flashcardsCompleted ? 'Completed' : 'Not Started';

  /// Video status: 'Not Watched' or 'Watched'.
  String get videoStatus => videoWatched ? 'Watched' : 'Not Watched';

  /// Constructs a [UserExercise] from a Firestore document snapshot.
  factory UserExercise.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return UserExercise(
      id: doc.id,
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      exerciseNumber: (data['exercise_number'] as num? ?? 0).toInt(),
      status: _parseStatus(data['status']),
      bestRating: (data['best_rating'] as num?)?.toInt(),
      timesAttempted: (data['times_attempted'] as num? ?? 0).toInt(),
      ratingHistory: List<int>.from(data['rating_history'] ?? []),
      lastAttempted: (data['last_attempted'] as Timestamp?)?.toDate(),
      videoWatched: data['video_watched'] ?? false,
      briefViewed: data['brief_viewed'] ?? false,
      flashcardsCompleted: data['flashcards_completed'] ?? false,
      weatherChecked: data['weather_checked'] ?? false,
      quizPassed: data['quiz_passed'] ?? false,
      quizAttempted: data['quiz_attempted'] ?? false,
      visualisationViewed: data['visualisation_viewed'] ?? false,
      spacedRepDue: (data['spaced_rep_due'] as Timestamp?)?.toDate(),
      quizMastery: Map<String, int>.from(
        ((data['quiz_mastery'] as Map<String, dynamic>?) ?? {})
            .map((k, v) => MapEntry(k, (v as num).toInt())),
      ),
      checklistCompleted: List<int>.from(data['checklist_completed'] ?? []),
    );
  }

  static ExerciseStatus _parseStatus(String? value) {
    switch (value) {
      case 'in_progress':
        return ExerciseStatus.inProgress;
      case 'complete': // legacy migration
        return ExerciseStatus.completedSatisfactory;
      case 'completed_unsatisfactory':
        return ExerciseStatus.completedUnsatisfactory;
      case 'completed_satisfactory':
        return ExerciseStatus.completedSatisfactory;
      default:
        return ExerciseStatus.notStarted;
    }
  }

  /// Serialises this record to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'exercise_id': exerciseId,
    if (subExercise != null) 'sub_exercise': subExercise,
    'exercise_number': exerciseNumber,
    'status': switch (status) {
      ExerciseStatus.notStarted => 'not_started',
      ExerciseStatus.inProgress => 'in_progress',
      ExerciseStatus.completedUnsatisfactory => 'completed_unsatisfactory',
      ExerciseStatus.completedSatisfactory => 'completed_satisfactory',
    },
    if (bestRating != null) 'best_rating': bestRating,
    'times_attempted': timesAttempted,
    'rating_history': ratingHistory,
    if (lastAttempted != null)
      'last_attempted': Timestamp.fromDate(lastAttempted!),
    'video_watched': videoWatched,
    'brief_viewed': briefViewed,
    'flashcards_completed': flashcardsCompleted,
    'weather_checked': weatherChecked,
    'quiz_passed': quizPassed,
    'quiz_attempted': quizAttempted,
    'visualisation_viewed': visualisationViewed,
    if (spacedRepDue != null)
      'spaced_rep_due': Timestamp.fromDate(spacedRepDue!),
    if (quizMastery.isNotEmpty) 'quiz_mastery': quizMastery,
    if (checklistCompleted.isNotEmpty)
      'checklist_completed': checklistCompleted,
  };

  /// Returns a copy with the given fields replaced.
  UserExercise copyWith({
    String? id,
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
    bool? quizAttempted,
    bool? visualisationViewed,
    DateTime? spacedRepDue,
    Map<String, int>? quizMastery,
    List<int>? checklistCompleted,
  }) {
    return UserExercise(
      id: id ?? this.id,
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
      quizAttempted: quizAttempted ?? this.quizAttempted,
      visualisationViewed: visualisationViewed ?? this.visualisationViewed,
      spacedRepDue: spacedRepDue ?? this.spacedRepDue,
      quizMastery: quizMastery ?? this.quizMastery,
      checklistCompleted: checklistCompleted ?? this.checklistCompleted,
    );
  }
}

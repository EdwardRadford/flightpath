// Lesson model — maps to a document in `users/{uid}/lessons/{lessonId}`.
// userId is NOT stored on the model — ownership is expressed by the path.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Possible states in the lesson lifecycle state machine.
enum LessonStatus { scheduled, prepared, completed, cancelled, manualEntry }

/// A single flying lesson record including ratings, quiz results, weather,
/// AI debrief data, and pilot logbook fields.
class Lesson {
  final String id;
  final String exerciseId;
  final String subExercise; // '' when no sub-exercise
  final DateTime? scheduledDate;
  final String scheduledTime;
  final DateTime? lessonDate;
  final int lessonDuration; // minutes — 0 if not set
  final int? studentRating; // 1–5
  final int? instructorRating; // 1–5
  final String instructorNotes;
  final String personalReflection;
  final int quizScore; // 0–100 — 0 if not taken
  final bool? quizPassed;
  final int quizAttempts;
  final double? weatherWindSpeed;
  final String weatherWindDirection;
  final double? weatherVisibility;
  final double? weatherTemperature;
  final String weatherConditions;
  final String aiDebriefWell;
  final String aiDebriefImprove;
  final String aiDebriefFocus;
  final List<String> additionalExerciseIds;
  final LessonStatus status;
  final DateTime createdAt;

  // ── Logbook fields ────────────────────────────────────────────────────────
  final String aircraftRegistration; // e.g. "G-BXYZ"
  final String aircraftType; // e.g. "cessna_152"
  final String departureAirfield; // ICAO code, e.g. "EGBJ"
  final String arrivalAirfield; // ICAO code, e.g. "EGBJ"
  final int flightTimeMinutes; // total flight time in minutes
  final int dualTimeMinutes; // dual instruction time in minutes
  final int picTimeMinutes; // pilot-in-command time in minutes
  final int landings; // number of landings
  final String instructorName;
  final String remarks;
  final bool isDayFlight; // true = day, false = night
  final String customExerciseName; // free-text when exerciseId == 'custom'
  final bool isQxc; // true when this flight is the qualifying cross-country
  final Map<String, int>? criterionRatings; // per-criterion 1–5 ratings keyed by criterion key
  final String nextFocusSuggestion; // AI-generated next-lesson focus

  const Lesson({
    required this.id,
    required this.exerciseId,
    this.subExercise = '',
    this.scheduledDate,
    this.scheduledTime = '',
    this.lessonDate,
    this.lessonDuration = 0,
    this.studentRating,
    this.instructorRating,
    this.instructorNotes = '',
    this.personalReflection = '',
    this.quizScore = 0,
    this.quizPassed,
    this.quizAttempts = 0,
    this.weatherWindSpeed,
    this.weatherWindDirection = '',
    this.weatherVisibility,
    this.weatherTemperature,
    this.weatherConditions = '',
    this.aiDebriefWell = '',
    this.aiDebriefImprove = '',
    this.aiDebriefFocus = '',
    this.additionalExerciseIds = const [],
    required this.status,
    required this.createdAt,
    this.aircraftRegistration = '',
    this.aircraftType = '',
    this.departureAirfield = '',
    this.arrivalAirfield = '',
    this.flightTimeMinutes = 0,
    this.dualTimeMinutes = 0,
    this.picTimeMinutes = 0,
    this.landings = 0,
    this.instructorName = '',
    this.remarks = '',
    this.isDayFlight = true,
    this.customExerciseName = '',
    this.isQxc = false,
    this.criterionRatings,
    this.nextFocusSuggestion = '',
  });

  /// Constructs a [Lesson] from a Firestore document snapshot.
  factory Lesson.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return Lesson(
      id: doc.id,
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'] ?? '',
      scheduledDate: (data['scheduled_date'] as Timestamp?)?.toDate(),
      scheduledTime: data['scheduled_time'] ?? '',
      lessonDate: (data['lesson_date'] as Timestamp?)?.toDate(),
      lessonDuration: (data['lesson_duration'] as num? ?? 0).toInt(),
      studentRating: (data['student_rating'] as num?)?.toInt(),
      instructorRating: (data['instructor_rating'] as num?)?.toInt(),
      instructorNotes: data['instructor_notes'] ?? '',
      personalReflection: data['personal_reflection'] ?? '',
      quizScore: (data['quiz_score'] as num? ?? 0).toInt(),
      quizPassed: data['quiz_passed'],
      quizAttempts: (data['quiz_attempts'] as num? ?? 0).toInt(),
      weatherWindSpeed: (data['weather_wind_speed'] as num?)?.toDouble(),
      weatherWindDirection: data['weather_wind_direction'] ?? '',
      weatherVisibility: (data['weather_visibility'] as num?)?.toDouble(),
      weatherTemperature: (data['weather_temperature'] as num?)?.toDouble(),
      weatherConditions: data['weather_conditions'] ?? '',
      aiDebriefWell: data['ai_debrief_well'] ?? '',
      aiDebriefImprove: data['ai_debrief_improve'] ?? '',
      aiDebriefFocus: data['ai_debrief_focus'] ?? '',
      additionalExerciseIds: List<String>.from(
        data['additional_exercise_ids'] ?? [],
      ),
      status: _parseStatus(data['status']),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aircraftRegistration: data['aircraft_registration'] ?? '',
      aircraftType: data['aircraft_type'] ?? '',
      departureAirfield: data['departure_airfield'] ?? '',
      arrivalAirfield: data['arrival_airfield'] ?? '',
      flightTimeMinutes: (data['flight_time_minutes'] as num? ?? 0).toInt(),
      dualTimeMinutes: (data['dual_time_minutes'] as num? ?? 0).toInt(),
      picTimeMinutes: (data['pic_time_minutes'] as num? ?? 0).toInt(),
      landings: (data['landings'] as num? ?? 0).toInt(),
      instructorName: data['instructor_name'] ?? '',
      remarks: data['remarks'] ?? '',
      isDayFlight: data['is_day_flight'] ?? true,
      customExerciseName: data['custom_exercise_name'] ?? '',
      isQxc: data['is_qxc'] ?? false,
      criterionRatings: (data['criterion_ratings'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toInt())),
      nextFocusSuggestion: data['next_focus_suggestion'] ?? '',
    );
  }

  static LessonStatus _parseStatus(String? value) {
    switch (value) {
      case 'prepared':
        return LessonStatus.prepared;
      case 'completed':
        return LessonStatus.completed;
      case 'cancelled':
        return LessonStatus.cancelled;
      case 'manual_entry':
        return LessonStatus.manualEntry;
      default:
        return LessonStatus.scheduled;
    }
  }

  /// Combined session score (0–100).
  /// 60% from student rating (normalised), 40% from quiz score.
  /// Falls back to rating-only or quiz-only if one is missing.
  int? get sessionScore {
    final ratingNorm = studentRating != null ? studentRating! * 20 : null;
    final effectiveQuiz = quizScore > 0 ? quizScore : null;
    if (ratingNorm != null && effectiveQuiz != null) {
      return ((ratingNorm * 0.6) + (effectiveQuiz * 0.4)).round();
    }
    return ratingNorm ?? effectiveQuiz;
  }

  /// Serialises this lesson to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'exercise_id': exerciseId,
    if (subExercise.isNotEmpty) 'sub_exercise': subExercise,
    if (scheduledDate != null)
      'scheduled_date': Timestamp.fromDate(scheduledDate!),
    if (scheduledTime.isNotEmpty) 'scheduled_time': scheduledTime,
    if (lessonDate != null) 'lesson_date': Timestamp.fromDate(lessonDate!),
    if (lessonDuration > 0) 'lesson_duration': lessonDuration,
    if (studentRating != null) 'student_rating': studentRating,
    if (instructorRating != null) 'instructor_rating': instructorRating,
    if (instructorNotes.isNotEmpty) 'instructor_notes': instructorNotes,
    if (personalReflection.isNotEmpty)
      'personal_reflection': personalReflection,
    if (quizScore > 0) 'quiz_score': quizScore,
    if (quizPassed != null) 'quiz_passed': quizPassed,
    'quiz_attempts': quizAttempts,
    if (weatherWindSpeed != null) 'weather_wind_speed': weatherWindSpeed,
    if (weatherWindDirection.isNotEmpty)
      'weather_wind_direction': weatherWindDirection,
    if (weatherVisibility != null) 'weather_visibility': weatherVisibility,
    if (weatherTemperature != null)
      'weather_temperature': weatherTemperature,
    if (weatherConditions.isNotEmpty)
      'weather_conditions': weatherConditions,
    if (aiDebriefWell.isNotEmpty) 'ai_debrief_well': aiDebriefWell,
    if (aiDebriefImprove.isNotEmpty) 'ai_debrief_improve': aiDebriefImprove,
    if (aiDebriefFocus.isNotEmpty) 'ai_debrief_focus': aiDebriefFocus,
    if (additionalExerciseIds.isNotEmpty)
      'additional_exercise_ids': additionalExerciseIds,
    'status': status == LessonStatus.manualEntry
        ? 'manual_entry'
        : status.name,
    'created_at': Timestamp.fromDate(createdAt),
    if (aircraftRegistration.isNotEmpty)
      'aircraft_registration': aircraftRegistration,
    if (aircraftType.isNotEmpty) 'aircraft_type': aircraftType,
    if (departureAirfield.isNotEmpty) 'departure_airfield': departureAirfield,
    if (arrivalAirfield.isNotEmpty) 'arrival_airfield': arrivalAirfield,
    if (flightTimeMinutes > 0) 'flight_time_minutes': flightTimeMinutes,
    if (dualTimeMinutes > 0) 'dual_time_minutes': dualTimeMinutes,
    if (picTimeMinutes > 0) 'pic_time_minutes': picTimeMinutes,
    if (landings > 0) 'landings': landings,
    if (instructorName.isNotEmpty) 'instructor_name': instructorName,
    if (remarks.isNotEmpty) 'remarks': remarks,
    'is_day_flight': isDayFlight,
    if (customExerciseName.isNotEmpty)
      'custom_exercise_name': customExerciseName,
    if (isQxc) 'is_qxc': true,
    if (criterionRatings != null && criterionRatings!.isNotEmpty)
      'criterion_ratings': criterionRatings,
    if (nextFocusSuggestion.isNotEmpty)
      'next_focus_suggestion': nextFocusSuggestion,
  };

  /// Returns a copy of this lesson with the given fields replaced.
  Lesson copyWith({
    String? id,
    String? exerciseId,
    String? subExercise,
    DateTime? scheduledDate,
    String? scheduledTime,
    DateTime? lessonDate,
    int? lessonDuration,
    int? studentRating,
    int? instructorRating,
    String? instructorNotes,
    String? personalReflection,
    int? quizScore,
    bool? quizPassed,
    int? quizAttempts,
    double? weatherWindSpeed,
    String? weatherWindDirection,
    double? weatherVisibility,
    double? weatherTemperature,
    String? weatherConditions,
    String? aiDebriefWell,
    String? aiDebriefImprove,
    String? aiDebriefFocus,
    List<String>? additionalExerciseIds,
    LessonStatus? status,
    String? aircraftRegistration,
    String? aircraftType,
    String? departureAirfield,
    String? arrivalAirfield,
    int? flightTimeMinutes,
    int? dualTimeMinutes,
    int? picTimeMinutes,
    int? landings,
    String? instructorName,
    String? remarks,
    bool? isDayFlight,
    String? customExerciseName,
    bool? isQxc,
    Map<String, int>? criterionRatings,
    String? nextFocusSuggestion,
  }) {
    return Lesson(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      subExercise: subExercise ?? this.subExercise,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      lessonDate: lessonDate ?? this.lessonDate,
      lessonDuration: lessonDuration ?? this.lessonDuration,
      studentRating: studentRating ?? this.studentRating,
      instructorRating: instructorRating ?? this.instructorRating,
      instructorNotes: instructorNotes ?? this.instructorNotes,
      personalReflection: personalReflection ?? this.personalReflection,
      quizScore: quizScore ?? this.quizScore,
      quizPassed: quizPassed ?? this.quizPassed,
      quizAttempts: quizAttempts ?? this.quizAttempts,
      weatherWindSpeed: weatherWindSpeed ?? this.weatherWindSpeed,
      weatherWindDirection: weatherWindDirection ?? this.weatherWindDirection,
      weatherVisibility: weatherVisibility ?? this.weatherVisibility,
      weatherTemperature: weatherTemperature ?? this.weatherTemperature,
      weatherConditions: weatherConditions ?? this.weatherConditions,
      aiDebriefWell: aiDebriefWell ?? this.aiDebriefWell,
      aiDebriefImprove: aiDebriefImprove ?? this.aiDebriefImprove,
      aiDebriefFocus: aiDebriefFocus ?? this.aiDebriefFocus,
      additionalExerciseIds:
          additionalExerciseIds ?? this.additionalExerciseIds,
      status: status ?? this.status,
      createdAt: createdAt,
      aircraftRegistration: aircraftRegistration ?? this.aircraftRegistration,
      aircraftType: aircraftType ?? this.aircraftType,
      departureAirfield: departureAirfield ?? this.departureAirfield,
      arrivalAirfield: arrivalAirfield ?? this.arrivalAirfield,
      flightTimeMinutes: flightTimeMinutes ?? this.flightTimeMinutes,
      dualTimeMinutes: dualTimeMinutes ?? this.dualTimeMinutes,
      picTimeMinutes: picTimeMinutes ?? this.picTimeMinutes,
      landings: landings ?? this.landings,
      instructorName: instructorName ?? this.instructorName,
      remarks: remarks ?? this.remarks,
      isDayFlight: isDayFlight ?? this.isDayFlight,
      customExerciseName: customExerciseName ?? this.customExerciseName,
      isQxc: isQxc ?? this.isQxc,
      criterionRatings: criterionRatings ?? this.criterionRatings,
      nextFocusSuggestion: nextFocusSuggestion ?? this.nextFocusSuggestion,
    );
  }
}

// Lesson model — maps to a document in the Firestore `lessons` collection.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Possible states in the lesson lifecycle state machine.
enum LessonStatus { scheduled, prepared, completed, cancelled, manualEntry }

/// A single flying lesson record including ratings, quiz results, weather,
/// AI debrief data, and pilot logbook fields.
class Lesson {
  final String id;
  final String userId;
  final String exerciseId;
  final String? subExercise;
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final DateTime? lessonDate;
  final int? lessonDuration; // minutes
  final int? studentRating;  // 1–5
  final int? instructorRating; // 1–5
  final String? instructorNotes;
  final String? personalReflection;
  final int? quizScore;     // 0–100
  final bool? quizPassed;
  final int quizAttempts;
  final double? weatherWindSpeed;
  final String? weatherWindDirection;
  final double? weatherVisibility;
  final double? weatherTemperature;
  final String? weatherConditions;
  final String? aiDebriefWell;
  final String? aiDebriefImprove;
  final String? aiDebriefFocus;
  final List<String> additionalExerciseIds; // other exercises covered in this lesson
  final LessonStatus status;
  final DateTime createdAt;

  // ── Logbook fields ────────────────────────────────────────────────────────
  final String? aircraftRegistration; // e.g. "G-BXYZ"
  final String? aircraftType;         // e.g. "cessna_152"
  final String? departureAirfield;    // ICAO code, e.g. "EGBJ"
  final String? arrivalAirfield;      // ICAO code, e.g. "EGBJ"
  final int? flightTimeMinutes;       // total flight time in minutes
  final int? dualTimeMinutes;         // dual instruction time in minutes
  final int? picTimeMinutes;          // pilot-in-command time in minutes
  final int? landings;                // number of landings
  final String? instructorName;       // instructor name
  final String? remarks;              // logbook remarks / notes
  final bool isDayFlight;             // true = day, false = night
  final String? customExerciseName;   // free-text name when exerciseId == 'custom'

  const Lesson({
    required this.id,
    required this.userId,
    required this.exerciseId,
    this.subExercise,
    this.scheduledDate,
    this.scheduledTime,
    this.lessonDate,
    this.lessonDuration,
    this.studentRating,
    this.instructorRating,
    this.instructorNotes,
    this.personalReflection,
    this.quizScore,
    this.quizPassed,
    this.quizAttempts = 0,
    this.weatherWindSpeed,
    this.weatherWindDirection,
    this.weatherVisibility,
    this.weatherTemperature,
    this.weatherConditions,
    this.aiDebriefWell,
    this.aiDebriefImprove,
    this.aiDebriefFocus,
    this.additionalExerciseIds = const [],
    required this.status,
    required this.createdAt,
    this.aircraftRegistration,
    this.aircraftType,
    this.departureAirfield,
    this.arrivalAirfield,
    this.flightTimeMinutes,
    this.dualTimeMinutes,
    this.picTimeMinutes,
    this.landings,
    this.instructorName,
    this.remarks,
    this.isDayFlight = true,
    this.customExerciseName,
  });

  /// Constructs a [Lesson] from a Firestore document snapshot.
  factory Lesson.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lesson(
      id: doc.id,
      userId: data['user_id'] ?? '',
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      scheduledDate: (data['scheduled_date'] as Timestamp?)?.toDate(),
      scheduledTime: data['scheduled_time'],
      lessonDate: (data['lesson_date'] as Timestamp?)?.toDate(),
      lessonDuration: data['lesson_duration'],
      studentRating: data['student_rating'],
      instructorRating: data['instructor_rating'],
      instructorNotes: data['instructor_notes'],
      personalReflection: data['personal_reflection'],
      quizScore: data['quiz_score'],
      quizPassed: data['quiz_passed'],
      quizAttempts: data['quiz_attempts'] ?? 0,
      weatherWindSpeed: (data['weather_wind_speed'] as num?)?.toDouble(),
      weatherWindDirection: data['weather_wind_direction'],
      weatherVisibility: (data['weather_visibility'] as num?)?.toDouble(),
      weatherTemperature: (data['weather_temperature'] as num?)?.toDouble(),
      weatherConditions: data['weather_conditions'],
      aiDebriefWell: data['ai_debrief_well'],
      aiDebriefImprove: data['ai_debrief_improve'],
      aiDebriefFocus: data['ai_debrief_focus'],
      additionalExerciseIds: List<String>.from(data['additional_exercise_ids'] ?? []),
      status: _parseStatus(data['status']),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      aircraftRegistration: data['aircraft_registration'],
      aircraftType: data['aircraft_type'],
      departureAirfield: data['departure_airfield'],
      arrivalAirfield: data['arrival_airfield'],
      flightTimeMinutes: data['flight_time_minutes'],
      dualTimeMinutes: data['dual_time_minutes'],
      picTimeMinutes: data['pic_time_minutes'],
      landings: data['landings'],
      instructorName: data['instructor_name'],
      remarks: data['remarks'],
      isDayFlight: data['is_day_flight'] ?? true,
      customExerciseName: data['custom_exercise_name'],
    );
  }

  static LessonStatus _parseStatus(String? value) {
    switch (value) {
      case 'prepared': return LessonStatus.prepared;
      case 'completed': return LessonStatus.completed;
      case 'cancelled': return LessonStatus.cancelled;
      case 'manual_entry': return LessonStatus.manualEntry;
      default: return LessonStatus.scheduled;
    }
  }

  /// Combined session score (0–100).
  /// 60% from student rating (normalised), 40% from quiz score.
  /// Falls back to rating-only or quiz-only if one is missing.
  int? get sessionScore {
    final ratingNorm = studentRating != null ? studentRating! * 20 : null;
    if (ratingNorm != null && quizScore != null) {
      return ((ratingNorm * 0.6) + (quizScore! * 0.4)).round();
    }
    return ratingNorm ?? quizScore;
  }

  /// Serialises this lesson to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'exercise_id': exerciseId,
    if (subExercise != null) 'sub_exercise': subExercise,
    if (scheduledDate != null) 'scheduled_date': Timestamp.fromDate(scheduledDate!),
    if (scheduledTime != null) 'scheduled_time': scheduledTime,
    if (lessonDate != null) 'lesson_date': Timestamp.fromDate(lessonDate!),
    if (lessonDuration != null) 'lesson_duration': lessonDuration,
    if (studentRating != null) 'student_rating': studentRating,
    if (instructorRating != null) 'instructor_rating': instructorRating,
    if (instructorNotes != null) 'instructor_notes': instructorNotes,
    if (personalReflection != null) 'personal_reflection': personalReflection,
    if (quizScore != null) 'quiz_score': quizScore,
    if (quizPassed != null) 'quiz_passed': quizPassed,
    'quiz_attempts': quizAttempts,
    if (weatherWindSpeed != null) 'weather_wind_speed': weatherWindSpeed,
    if (weatherWindDirection != null) 'weather_wind_direction': weatherWindDirection,
    if (weatherVisibility != null) 'weather_visibility': weatherVisibility,
    if (weatherTemperature != null) 'weather_temperature': weatherTemperature,
    if (weatherConditions != null) 'weather_conditions': weatherConditions,
    if (aiDebriefWell != null) 'ai_debrief_well': aiDebriefWell,
    if (aiDebriefImprove != null) 'ai_debrief_improve': aiDebriefImprove,
    if (aiDebriefFocus != null) 'ai_debrief_focus': aiDebriefFocus,
    if (additionalExerciseIds.isNotEmpty) 'additional_exercise_ids': additionalExerciseIds,
    'status': status.name == 'manualEntry' ? 'manual_entry' : status.name,
    'created_at': Timestamp.fromDate(createdAt),
    if (aircraftRegistration != null) 'aircraft_registration': aircraftRegistration,
    if (aircraftType != null) 'aircraft_type': aircraftType,
    if (departureAirfield != null) 'departure_airfield': departureAirfield,
    if (arrivalAirfield != null) 'arrival_airfield': arrivalAirfield,
    if (flightTimeMinutes != null) 'flight_time_minutes': flightTimeMinutes,
    if (dualTimeMinutes != null) 'dual_time_minutes': dualTimeMinutes,
    if (picTimeMinutes != null) 'pic_time_minutes': picTimeMinutes,
    if (landings != null) 'landings': landings,
    if (instructorName != null) 'instructor_name': instructorName,
    if (remarks != null) 'remarks': remarks,
    'is_day_flight': isDayFlight,
    if (customExerciseName != null) 'custom_exercise_name': customExerciseName,
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
  }) {
    return Lesson(
      id: id ?? this.id,
      userId: userId,
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
      additionalExerciseIds: additionalExerciseIds ?? this.additionalExerciseIds,
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
    );
  }
}

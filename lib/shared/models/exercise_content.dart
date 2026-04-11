// Exercise content model — read-only content from the Firestore
// `exercise_content` collection (brief, tips, quiz metadata, media URLs).
// NO toFirestore() — this collection is never written to by the app.
import 'package:cloud_firestore/cloud_firestore.dart';

/// lesson_type drives conditional UI throughout the app.
/// NEVER check exercise numbers — always check lesson_type.
enum LessonType { flight, ground, milestone }

/// All static content for a single exercise or sub-exercise, loaded from
/// Firestore and cached locally via Hive.
class ExerciseContent {
  final String id;
  final int exerciseNumber;
  final String exerciseName;
  final String? subExercise; // e.g. '10A', '18B' — null if no sub-exercise
  final LessonType lessonType;
  final int contentVersion;

  // Brief content
  final String overview;
  final String aim;
  final String whatToExpect;
  final String keyFocusAreas;
  final String commonMistakes;
  final String preFlightChecklist;
  final String oneThingToNail;
  final String masteryCriteria;

  // Aircraft-specific tips — keyed by aircraft_type value (e.g. 'cessna_152')
  final Map<String, String> aircraftTips;

  // Media
  final String videoUrl;
  final String backupVideoUrl;

  // Learning mechanisms
  final String activeRecallPrompt;
  final String visualisationScript;

  const ExerciseContent({
    required this.id,
    required this.exerciseNumber,
    required this.exerciseName,
    this.subExercise,
    required this.lessonType,
    required this.contentVersion,
    required this.overview,
    required this.aim,
    required this.whatToExpect,
    required this.keyFocusAreas,
    required this.commonMistakes,
    required this.preFlightChecklist,
    required this.oneThingToNail,
    required this.masteryCriteria,
    this.aircraftTips = const {},
    required this.videoUrl,
    required this.backupVideoUrl,
    required this.activeRecallPrompt,
    required this.visualisationScript,
  });

  /// Constructs an [ExerciseContent] from a Firestore document snapshot.
  factory ExerciseContent.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return ExerciseContent(
      id: doc.id,
      exerciseNumber: (data['exercise_number'] as num?)?.toInt() ?? 0,
      exerciseName: data['exercise_name'] ?? '',
      subExercise: data['sub_exercise'],
      lessonType: _parseLessonType(data['lesson_type']),
      contentVersion: (data['content_version'] as num?)?.toInt() ?? 1,
      overview: data['overview'] ?? '',
      aim: data['aim'] ?? '',
      whatToExpect: data['what_to_expect'] ?? '',
      keyFocusAreas: data['key_focus_areas'] ?? '',
      commonMistakes: data['common_mistakes'] ?? '',
      preFlightChecklist: data['pre_flight_checklist'] ?? '',
      oneThingToNail: data['one_thing_to_nail'] ?? '',
      masteryCriteria: data['mastery_criteria'] ?? '',
      aircraftTips: _parseAircraftTips(data),
      videoUrl: data['video_url'] ?? '',
      backupVideoUrl: data['backup_video_url'] ?? '',
      activeRecallPrompt: data['active_recall_prompt'] ?? '',
      visualisationScript: data['visualisation_script'] ?? '',
    );
  }

  /// Constructs an [ExerciseContent] from a plain map (e.g. from Hive cache).
  factory ExerciseContent.fromMap(String docId, Map<String, dynamic> data) {
    return ExerciseContent(
      id: docId,
      exerciseNumber: (data['exercise_number'] as num?)?.toInt() ?? 0,
      exerciseName: data['exercise_name'] ?? '',
      subExercise: data['sub_exercise'],
      lessonType: _parseLessonType(data['lesson_type']),
      contentVersion: (data['content_version'] as num?)?.toInt() ?? 1,
      overview: data['overview'] ?? '',
      aim: data['aim'] ?? '',
      whatToExpect: data['what_to_expect'] ?? '',
      keyFocusAreas: data['key_focus_areas'] ?? '',
      commonMistakes: data['common_mistakes'] ?? '',
      preFlightChecklist: data['pre_flight_checklist'] ?? '',
      oneThingToNail: data['one_thing_to_nail'] ?? '',
      masteryCriteria: data['mastery_criteria'] ?? '',
      aircraftTips: _parseAircraftTips(data),
      videoUrl: data['video_url'] ?? '',
      backupVideoUrl: data['backup_video_url'] ?? '',
      activeRecallPrompt: data['active_recall_prompt'] ?? '',
      visualisationScript: data['visualisation_script'] ?? '',
    );
  }

  static LessonType _parseLessonType(String? value) {
    switch (value) {
      case 'ground':
        return LessonType.ground;
      case 'milestone':
        return LessonType.milestone;
      default:
        return LessonType.flight;
    }
  }

  /// Parses all `aircraft_tips_*` fields from a Firestore/Hive data map into a
  /// map keyed by aircraft_type value (e.g. 'cessna_152' → tip text).
  static Map<String, String> _parseAircraftTips(Map<String, dynamic> data) {
    const fieldToType = {
      'aircraft_tips_c152': 'cessna_152',
      'aircraft_tips_c172': 'cessna_172',
      'aircraft_tips_pa28': 'pa28',
      'aircraft_tips_pa28_181': 'pa28_181',
      'aircraft_tips_pa38': 'pa38',
      'aircraft_tips_da20': 'da20',
      'aircraft_tips_da40': 'da40',
      'aircraft_tips_robin_dr400': 'robin_dr400',
      'aircraft_tips_grob_g115': 'grob_g115',
      'aircraft_tips_tecnam_p2002': 'tecnam_p2002',
    };
    final tips = <String, String>{};
    for (final entry in fieldToType.entries) {
      final value = data[entry.key];
      if (value != null && value is String && value.isNotEmpty) {
        tips[entry.value] = value;
      }
    }
    return tips;
  }

  /// Returns aircraft-specific tip for the user's aircraft type.
  String tipsForAircraft(String aircraftType) {
    return aircraftTips[aircraftType] ?? '';
  }

  /// Human-readable label, e.g. "Exercise 10A: Slow Flight".
  String get displayName => subExercise != null
      ? 'Exercise $subExercise: $exerciseName'
      : 'Exercise $exerciseNumber: $exerciseName';

  /// Serialises this content to a plain map (for Hive caching only).
  Map<String, dynamic> toMap() => {
    'exercise_number': exerciseNumber,
    'exercise_name': exerciseName,
    if (subExercise != null) 'sub_exercise': subExercise,
    'lesson_type': lessonType.name,
    'content_version': contentVersion,
    'overview': overview,
    'aim': aim,
    'what_to_expect': whatToExpect,
    'key_focus_areas': keyFocusAreas,
    'common_mistakes': commonMistakes,
    'pre_flight_checklist': preFlightChecklist,
    'one_thing_to_nail': oneThingToNail,
    'mastery_criteria': masteryCriteria,
    if (aircraftTips.containsKey('cessna_152'))
      'aircraft_tips_c152': aircraftTips['cessna_152'],
    if (aircraftTips.containsKey('cessna_172'))
      'aircraft_tips_c172': aircraftTips['cessna_172'],
    if (aircraftTips.containsKey('pa28'))
      'aircraft_tips_pa28': aircraftTips['pa28'],
    if (aircraftTips.containsKey('pa28_181'))
      'aircraft_tips_pa28_181': aircraftTips['pa28_181'],
    if (aircraftTips.containsKey('pa38'))
      'aircraft_tips_pa38': aircraftTips['pa38'],
    if (aircraftTips.containsKey('da20'))
      'aircraft_tips_da20': aircraftTips['da20'],
    if (aircraftTips.containsKey('da40'))
      'aircraft_tips_da40': aircraftTips['da40'],
    if (aircraftTips.containsKey('robin_dr400'))
      'aircraft_tips_robin_dr400': aircraftTips['robin_dr400'],
    if (aircraftTips.containsKey('grob_g115'))
      'aircraft_tips_grob_g115': aircraftTips['grob_g115'],
    if (aircraftTips.containsKey('tecnam_p2002'))
      'aircraft_tips_tecnam_p2002': aircraftTips['tecnam_p2002'],
    'video_url': videoUrl,
    'backup_video_url': backupVideoUrl,
    'active_recall_prompt': activeRecallPrompt,
    'visualisation_script': visualisationScript,
  };

  /// Returns a copy with the given fields replaced.
  ExerciseContent copyWith({
    String? id,
    int? exerciseNumber,
    String? exerciseName,
    String? subExercise,
    LessonType? lessonType,
    int? contentVersion,
    String? overview,
    String? aim,
    String? whatToExpect,
    String? keyFocusAreas,
    String? commonMistakes,
    String? preFlightChecklist,
    String? oneThingToNail,
    String? masteryCriteria,
    Map<String, String>? aircraftTips,
    String? videoUrl,
    String? backupVideoUrl,
    String? activeRecallPrompt,
    String? visualisationScript,
  }) {
    return ExerciseContent(
      id: id ?? this.id,
      exerciseNumber: exerciseNumber ?? this.exerciseNumber,
      exerciseName: exerciseName ?? this.exerciseName,
      subExercise: subExercise ?? this.subExercise,
      lessonType: lessonType ?? this.lessonType,
      contentVersion: contentVersion ?? this.contentVersion,
      overview: overview ?? this.overview,
      aim: aim ?? this.aim,
      whatToExpect: whatToExpect ?? this.whatToExpect,
      keyFocusAreas: keyFocusAreas ?? this.keyFocusAreas,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      preFlightChecklist: preFlightChecklist ?? this.preFlightChecklist,
      oneThingToNail: oneThingToNail ?? this.oneThingToNail,
      masteryCriteria: masteryCriteria ?? this.masteryCriteria,
      aircraftTips: aircraftTips ?? this.aircraftTips,
      videoUrl: videoUrl ?? this.videoUrl,
      backupVideoUrl: backupVideoUrl ?? this.backupVideoUrl,
      activeRecallPrompt: activeRecallPrompt ?? this.activeRecallPrompt,
      visualisationScript: visualisationScript ?? this.visualisationScript,
    );
  }
}

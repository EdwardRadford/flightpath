// Exercise content model — read-only content from the Firestore
// `exercise_content` collection (brief, tips, quiz metadata, media URLs).
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

  // Aircraft-specific tips
  final String aircraftTipsC152;
  final String aircraftTipsC172;
  final String aircraftTipsPa28;
  final String aircraftTipsDa40;

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
    required this.aircraftTipsC152,
    required this.aircraftTipsC172,
    required this.aircraftTipsPa28,
    required this.aircraftTipsDa40,
    required this.videoUrl,
    required this.backupVideoUrl,
    required this.activeRecallPrompt,
    required this.visualisationScript,
  });

  /// Constructs an [ExerciseContent] from a Firestore document snapshot.
  factory ExerciseContent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExerciseContent(
      id: doc.id,
      exerciseNumber: data['exercise_number'] ?? 0,
      exerciseName: data['exercise_name'] ?? '',
      subExercise: data['sub_exercise'],
      lessonType: _parseLessonType(data['lesson_type']),
      contentVersion: data['content_version'] ?? 1,
      overview: data['overview'] ?? '',
      aim: data['aim'] ?? '',
      whatToExpect: data['what_to_expect'] ?? '',
      keyFocusAreas: data['key_focus_areas'] ?? '',
      commonMistakes: data['common_mistakes'] ?? '',
      preFlightChecklist: data['pre_flight_checklist'] ?? '',
      oneThingToNail: data['one_thing_to_nail'] ?? '',
      masteryCriteria: data['mastery_criteria'] ?? '',
      aircraftTipsC152: data['aircraft_tips_c152'] ?? '',
      aircraftTipsC172: data['aircraft_tips_c172'] ?? '',
      aircraftTipsPa28: data['aircraft_tips_pa28'] ?? '',
      aircraftTipsDa40: data['aircraft_tips_da40'] ?? '',
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
      exerciseNumber: data['exercise_number'] ?? 0,
      exerciseName: data['exercise_name'] ?? '',
      subExercise: data['sub_exercise'],
      lessonType: _parseLessonType(data['lesson_type']),
      contentVersion: data['content_version'] ?? 1,
      overview: data['overview'] ?? '',
      aim: data['aim'] ?? '',
      whatToExpect: data['what_to_expect'] ?? '',
      keyFocusAreas: data['key_focus_areas'] ?? '',
      commonMistakes: data['common_mistakes'] ?? '',
      preFlightChecklist: data['pre_flight_checklist'] ?? '',
      oneThingToNail: data['one_thing_to_nail'] ?? '',
      masteryCriteria: data['mastery_criteria'] ?? '',
      aircraftTipsC152: data['aircraft_tips_c152'] ?? '',
      aircraftTipsC172: data['aircraft_tips_c172'] ?? '',
      aircraftTipsPa28: data['aircraft_tips_pa28'] ?? '',
      aircraftTipsDa40: data['aircraft_tips_da40'] ?? '',
      videoUrl: data['video_url'] ?? '',
      backupVideoUrl: data['backup_video_url'] ?? '',
      activeRecallPrompt: data['active_recall_prompt'] ?? '',
      visualisationScript: data['visualisation_script'] ?? '',
    );
  }

  static LessonType _parseLessonType(String? value) {
    switch (value) {
      case 'ground': return LessonType.ground;
      case 'milestone': return LessonType.milestone;
      default: return LessonType.flight;
    }
  }

  /// Returns aircraft-specific tip for the user's aircraft type.
  String tipsForAircraft(String aircraftType) {
    switch (aircraftType) {
      case 'cessna_152': return aircraftTipsC152;
      case 'cessna_172': return aircraftTipsC172;
      case 'pa28': return aircraftTipsPa28;
      case 'da40': return aircraftTipsDa40;
      default: return '';
    }
  }

  /// Human-readable label, e.g. "Exercise 10A: Slow Flight".
  String get displayName =>
      subExercise != null ? 'Exercise $subExercise: $exerciseName' : 'Exercise $exerciseNumber: $exerciseName';

  /// Serialises this content to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'exercise_number': exerciseNumber,
        'exercise_name': exerciseName,
        'sub_exercise': subExercise,
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
        'aircraft_tips_c152': aircraftTipsC152,
        'aircraft_tips_c172': aircraftTipsC172,
        'aircraft_tips_pa28': aircraftTipsPa28,
        'aircraft_tips_da40': aircraftTipsDa40,
        'video_url': videoUrl,
        'backup_video_url': backupVideoUrl,
        'active_recall_prompt': activeRecallPrompt,
        'visualisation_script': visualisationScript,
      };
}

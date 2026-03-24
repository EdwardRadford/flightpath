// Utility functions for parsing, building, and formatting exercise IDs and names.
import 'package:flight_path/core/constants/app_constants.dart';

/// Parses a composite route ID like 'ex_10_10a' into a base exercise ID
/// and an optional sub-exercise key.
///
/// Returns a record of (baseId, subExerciseKey?).
///   'ex_10_10a' → ('ex_10', '10a')
///   'ex_05'     → ('ex_05', null)
(String, String?) parseExerciseId(String compositeId) {
  final parts = compositeId.split('_');
  if (parts.length >= 3) {
    return ('${parts[0]}_${parts[1]}', parts.sublist(2).join('_'));
  }
  return (compositeId, null);
}

/// Builds a composite ID from a base exercise ID and optional sub-exercise key.
///   ('ex_10', '10a') → 'ex_10_10a'
///   ('ex_05', null)  → 'ex_05'
String compositeExerciseId(String exerciseId, String? subExerciseId) =>
    subExerciseId != null ? '${exerciseId}_$subExerciseId' : exerciseId;

/// Short name: "Exercise 1", "Exercise 10A"
String exerciseDisplayName(String exerciseId) {
  return AppConstants.exerciseNames[exerciseId] ?? exerciseId;
}

/// Full CAA title: "Familiarisation with the Aeroplane"
String exerciseFullName(String exerciseId) {
  return AppConstants.exerciseTitles[exerciseId] ??
      AppConstants.exerciseNames[exerciseId] ??
      exerciseId;
}

/// Compact label: "Ex 1 – Familiarisation"
String exerciseCompactName(String exerciseId) {
  final short = AppConstants.exerciseNames[exerciseId];
  final title = AppConstants.exerciseTitles[exerciseId];
  if (short == null || title == null) return exerciseId;
  final compact = short.replaceAll('Exercise ', 'Ex ');
  return '$compact – $title';
}

/// Long label: "Exercise 1 – Familiarisation"
String exerciseLongName(String exerciseId) {
  final short = AppConstants.exerciseNames[exerciseId];
  final title = AppConstants.exerciseTitles[exerciseId];
  if (short == null || title == null) return exerciseId;
  return '$short – $title';
}

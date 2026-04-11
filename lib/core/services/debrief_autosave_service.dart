// Debrief autosave service — persists debrief form fields to SharedPreferences
// with a debounced 2-second delay so data survives app kills and restarts.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys used to store drafts — namespaced per exercise to avoid collisions.
String _draftKey(String exerciseId) => 'debrief_draft_$exerciseId';

/// A snapshot of the debrief form fields that can be persisted.
class DebriefDraft {
  final String exerciseId;
  final int studentRating;
  final String instructorNotes;
  final String personalReflection;
  final String soloDuration;
  final int durationHours;
  final int durationMinutes;
  final List<String> additionalExerciseIds;
  final DateTime savedAt;

  DebriefDraft({
    required this.exerciseId,
    required this.studentRating,
    required this.instructorNotes,
    required this.personalReflection,
    required this.soloDuration,
    required this.durationHours,
    required this.durationMinutes,
    required this.additionalExerciseIds,
    required this.savedAt,
  });

  Map<String, dynamic> toJson() => {
        'exercise_id': exerciseId,
        'student_rating': studentRating,
        'instructor_notes': instructorNotes,
        'personal_reflection': personalReflection,
        'solo_duration': soloDuration,
        'duration_hours': durationHours,
        'duration_minutes': durationMinutes,
        'additional_exercise_ids': additionalExerciseIds,
        'saved_at': savedAt.toIso8601String(),
      };

  factory DebriefDraft.fromJson(Map<String, dynamic> json) {
    return DebriefDraft(
      exerciseId: json['exercise_id'] as String? ?? '',
      studentRating: json['student_rating'] as int? ?? 3,
      instructorNotes: json['instructor_notes'] as String? ?? '',
      personalReflection: json['personal_reflection'] as String? ?? '',
      soloDuration: json['solo_duration'] as String? ?? '',
      durationHours: json['duration_hours'] as int? ?? 1,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      additionalExerciseIds: (json['additional_exercise_ids'] as List<dynamic>?)
              ?.cast<String>() ??
          [],
      savedAt: json['saved_at'] != null
          ? DateTime.tryParse(json['saved_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Returns true if the draft has meaningful content worth restoring.
  bool get hasContent =>
      instructorNotes.trim().isNotEmpty ||
      personalReflection.trim().isNotEmpty ||
      soloDuration.trim().isNotEmpty ||
      additionalExerciseIds.isNotEmpty ||
      studentRating != 3;
}

/// Manages debounced autosave and restore of debrief form drafts.
class DebriefAutosaveService {
  Timer? _debounceTimer;

  /// Saves a draft after a 2-second debounce delay.
  void saveDraft(DebriefDraft draft) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _draftKey(draft.exerciseId),
        jsonEncode(draft.toJson()),
      );
    });
  }

  /// Immediately saves a draft without debouncing (for use on dispose).
  Future<void> saveDraftImmediately(DebriefDraft draft) async {
    _debounceTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _draftKey(draft.exerciseId),
      jsonEncode(draft.toJson()),
    );
  }

  /// Loads a saved draft for the given exercise, or null if none exists.
  Future<DebriefDraft?> loadDraft(String exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey(exerciseId));
    if (raw == null) return null;

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final draft = DebriefDraft.fromJson(json);

      // Discard drafts older than 7 days — they're likely stale.
      if (DateTime.now().difference(draft.savedAt).inDays > 7) {
        await clearDraft(exerciseId);
        return null;
      }

      return draft.hasContent ? draft : null;
    } catch (_) {
      // Corrupted data — remove it.
      await clearDraft(exerciseId);
      return null;
    }
  }

  /// Removes the saved draft for the given exercise (after successful submit).
  Future<void> clearDraft(String exerciseId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey(exerciseId));
  }

  /// Cancels any pending debounce timer.
  void dispose() {
    _debounceTimer?.cancel();
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides a [DebriefAutosaveService] instance scoped to the widget lifetime.
/// Each debrief screen should read this once and dispose when done.
final debriefAutosaveServiceProvider = Provider<DebriefAutosaveService>((ref) {
  final service = DebriefAutosaveService();
  ref.onDispose(service.dispose);
  return service;
});

// Debrief screen — post-lesson form collecting ratings, reflections, and
// weather, then calling the Claude API for AI-generated feedback.
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/exercise_criteria.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/features/lesson_log/widgets/lesson_form.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/connectivity_service.dart';
import 'package:flight_path/shared/services/debrief_autosave_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/services/notification_service.dart';
import 'package:flight_path/shared/services/offline_lesson_service.dart';
import 'package:flight_path/shared/services/rate_app_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/connectivity_banner.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

/// Post-lesson debrief form with ratings, reflections, and AI-powered feedback.
/// When [existingLesson] is provided, the screen operates in edit mode:
/// form fields are pre-filled and saving updates the existing document
/// instead of creating a new one. AI debrief is only triggered on initial
/// creation, not on edits.
class DebriefScreen extends ConsumerStatefulWidget {
  final String exerciseId;
  final Lesson? existingLesson;

  const DebriefScreen({
    super.key,
    required this.exerciseId,
    this.existingLesson,
  });

  @override
  ConsumerState<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends ConsumerState<DebriefScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LessonFormController _form;

  bool get _isEditMode => widget.existingLesson != null;

  bool _paywallLogged = false;
  bool _saving = false;
  bool _draftSaved = false;
  Timer? _savedIndicatorTimer;

  // Autosave
  late final DebriefAutosaveService _autosave;
  bool _formInstructorPrefilled = false;

  @override
  void initState() {
    super.initState();
    _autosave = ref.read(debriefAutosaveServiceProvider);
    _form = LessonFormController();

    if (_isEditMode) {
      final lesson = widget.existingLesson!;
      _form.studentRating = lesson.studentRating ?? 3;
      _form.instructorNotes.text = lesson.instructorNotes;
      _form.personalReflection.text = lesson.personalReflection;
      if (lesson.lessonDuration > 0) {
        _form.flightHours = lesson.lessonDuration ~/ 60;
        _form.flightMinutes = lesson.lessonDuration % 60;
      }
      _form.exerciseIds.addAll(lesson.additionalExerciseIds);

      // New logbook fields — older lessons stored before 2026-04-29 simply
      // have empty defaults; the form is happy with that.
      _form.aircraftType = lesson.aircraftType;
      _form.registration.text = lesson.aircraftRegistration;
      _form.departureIcao.text = lesson.departureAirfield;
      _form.arrivalIcao.text = lesson.arrivalAirfield;
      _form.landings = lesson.landings;
      _form.instructorName.text = lesson.instructorName;
      _form.isDayFlight = lesson.isDayFlight;
      _form.criterionRatings.addAll(lesson.criterionRatings ?? const {});
      // Best-effort role inference from saved time fields.
      if (lesson.picTimeMinutes > 0 && lesson.dualTimeMinutes == 0) {
        _form.pilotRole = PilotRole.pic;
      } else if (lesson.dualTimeMinutes > 0 && lesson.picTimeMinutes == 0) {
        _form.pilotRole = PilotRole.dual;
      }
      _formInstructorPrefilled = true;
    } else {
      _autosave.loadDraft(widget.exerciseId).then((result) {
        if (!mounted) return;
        if (result.wasExpired) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'A previous draft was found but was too old and has been discarded.'),
            ),
          );
        } else if (result.draft != null) {
          _showRestoreDraftDialog(result.draft!);
        }
      });
    }
  }

  /// Pre-fill aircraft type from the user's profile and the instructor name
  /// from the most recent lesson — only on initial creation, only if the user
  /// hasn't typed anything in those fields yet.
  void _maybePrefillDefaults() {
    if (_isEditMode || _formInstructorPrefilled) return;
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      if (_form.aircraftType.isEmpty && user.aircraftType.isNotEmpty) {
        _form.aircraftType = user.aircraftType;
      }
      if (_form.departureIcao.text.isEmpty && user.airfieldIcao.isNotEmpty) {
        _form.departureIcao.text = user.airfieldIcao.toUpperCase();
      }
      if (_form.arrivalIcao.text.isEmpty && user.airfieldIcao.isNotEmpty) {
        _form.arrivalIcao.text = user.airfieldIcao.toUpperCase();
      }
    }
    final lastInstructor = ref.read(lastInstructorNameProvider);
    if (_form.instructorName.text.isEmpty && lastInstructor != null) {
      _form.instructorName.text = lastInstructor;
    }
    _formInstructorPrefilled = true;
  }

  void _onFieldChanged() {
    if (!_isEditMode) {
      setState(() => _draftSaved = true);
      _savedIndicatorTimer?.cancel();
      _savedIndicatorTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _draftSaved = false);
      });
    }
    _autosave.saveDraft(DebriefDraft(
      exerciseId: widget.exerciseId,
      studentRating: _form.studentRating,
      instructorNotes: _form.instructorNotes.text,
      personalReflection: _form.personalReflection.text,
      soloDuration: _form.soloDuration.text,
      durationHours: _form.flightHours,
      durationMinutes: _form.flightMinutes,
      additionalExerciseIds: _form.exerciseIds.toList(),
      aircraftType: _form.aircraftType,
      registration: _form.registration.text,
      departureIcao: _form.departureIcao.text,
      arrivalIcao: _form.arrivalIcao.text,
      pilotRole: _form.pilotRole.name,
      landings: _form.landings,
      instructorName: _form.instructorName.text,
      isDayFlight: _form.isDayFlight,
      savedAt: DateTime.now(),
    ));
  }

  void _showRestoreDraftDialog(DebriefDraft draft) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved Debrief'),
        content: const Text(
            'You have an unsaved debrief. Resume where you left off?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _autosave.clearDraft(widget.exerciseId);
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _restoreDraft(draft);
            },
            child: const Text('Resume'),
          ),
        ],
      ),
    );
  }

  void _restoreDraft(DebriefDraft draft) {
    setState(() {
      _form.studentRating = draft.studentRating;
      _form.instructorNotes.text = draft.instructorNotes;
      _form.personalReflection.text = draft.personalReflection;
      _form.soloDuration.text = draft.soloDuration;
      _form.flightHours = draft.durationHours;
      _form.flightMinutes = draft.durationMinutes;
      _form.exerciseIds
        ..clear()
        ..addAll(draft.additionalExerciseIds);
      _form.aircraftType = draft.aircraftType;
      _form.registration.text = draft.registration;
      _form.departureIcao.text = draft.departureIcao;
      _form.arrivalIcao.text = draft.arrivalIcao;
      _form.pilotRole = PilotRole.values.firstWhere(
        (r) => r.name == draft.pilotRole,
        orElse: () => PilotRole.dual,
      );
      _form.landings = draft.landings;
      _form.instructorName.text = draft.instructorName;
      _form.isDayFlight = draft.isDayFlight;
    });
    _formInstructorPrefilled = true;
  }

  @override
  void dispose() {
    _savedIndicatorTimer?.cancel();
    _form.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save({
    required String? uid,
    required LessonType lessonType,
    required List<int> existingHistory,
    required UserExercise? existingUE,
  }) async {
    if (_saving) return; // Guard against double-submission
    if (uid == null) return;
    if (!_formKey.currentState!.validate()) return;

    // ── Edit mode ────────────────────────────────────────────────────────────
    if (_isEditMode) {
      setState(() => _saving = true);
      try {
        final offlineService = ref.read(offlineLessonServiceProvider);
        int? durationMinutes;
        if (lessonType == LessonType.flight) {
          durationMinutes = _form.flightHours * 60 + _form.flightMinutes;
        } else if (lessonType == LessonType.milestone) {
          final text = _form.soloDuration.text.trim();
          if (text.isNotEmpty) durationMinutes = int.tryParse(text);
        }

        final dualMin =
            _form.pilotRole == PilotRole.dual ? (durationMinutes ?? 0) : 0;
        final picMin =
            _form.pilotRole == PilotRole.pic ? (durationMinutes ?? 0) : 0;

        final data = <String, dynamic>{
          'student_rating': _form.studentRating,
          'instructor_notes': _sanitise(_form.instructorNotes.text).isEmpty
              ? null
              : _sanitise(_form.instructorNotes.text),
          'personal_reflection': _sanitise(_form.personalReflection.text).isEmpty
              ? null
              : _sanitise(_form.personalReflection.text),
          if (durationMinutes != null) 'lesson_duration': durationMinutes,
          'additional_exercise_ids': _form.exerciseIds.toList(),
          // ── New logbook fields ─────────────────────────────────────────
          'aircraft_type': _form.aircraftType,
          'aircraft_registration':
              _form.registration.text.trim().toUpperCase(),
          'departure_airfield':
              _form.departureIcao.text.trim().toUpperCase(),
          'arrival_airfield': _form.arrivalIcao.text.trim().toUpperCase(),
          'landings': _form.landings,
          'instructor_name': _sanitise(_form.instructorName.text),
          'is_day_flight': _form.isDayFlight,
          if (durationMinutes != null) 'flight_time_minutes': durationMinutes,
          'dual_time_minutes': dualMin,
          'pic_time_minutes': picMin,
        };

        await offlineService.updateLesson(uid, widget.existingLesson!.id, data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debrief updated!'),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      } catch (e, st) {
        FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error updating debrief. Please try again.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    // ── Create mode ──────────────────────────────────────────────────────────
    setState(() => _saving = true);

    final (exerciseId, subExerciseId) = parseExerciseId(widget.exerciseId);
    final firestore = ref.read(firestoreServiceProvider);
    final offlineLessons = ref.read(offlineLessonServiceProvider);
    final isOnline = ref.read(isOnlineProvider);

    try {
      int? soloMinutes;
      if (lessonType == LessonType.milestone) {
        final text = _form.soloDuration.text.trim();
        if (text.isNotEmpty) soloMinutes = int.tryParse(text);
      }

      int? durationMinutes;
      if (lessonType == LessonType.flight) {
        durationMinutes = _form.flightHours * 60 + _form.flightMinutes;
        if (durationMinutes <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please enter a flight duration.'),
                backgroundColor: AppColors.error,
              ),
            );
            setState(() => _saving = false);
          }
          return;
        }
      } else if (lessonType == LessonType.milestone && soloMinutes != null) {
        durationMinutes = soloMinutes;
      }

      final dualMin = _form.pilotRole == PilotRole.dual
          ? (durationMinutes ?? 0)
          : 0;
      final picMin = _form.pilotRole == PilotRole.pic
          ? (durationMinutes ?? 0)
          : 0;

      final lesson = Lesson(
        id: '',
        exerciseId: exerciseId,
        subExercise: subExerciseId ?? '',
        studentRating: _form.studentRating,
        instructorRating: null,
        lessonDuration: durationMinutes ?? 0,
        instructorNotes: _sanitise(_form.instructorNotes.text),
        personalReflection: _sanitise(_form.personalReflection.text),
        additionalExerciseIds: _form.exerciseIds.toList(),
        lessonDate: DateTime.now(),
        status: LessonStatus.completed,
        createdAt: DateTime.now(),
        criterionRatings: _form.criterionRatings.isNotEmpty
            ? Map<String, int>.from(_form.criterionRatings)
            : null,
        aircraftType: _form.aircraftType,
        aircraftRegistration: _form.registration.text.trim().toUpperCase(),
        departureAirfield: _form.departureIcao.text.trim().toUpperCase(),
        arrivalAirfield: _form.arrivalIcao.text.trim().toUpperCase(),
        flightTimeMinutes: durationMinutes ?? 0,
        dualTimeMinutes: dualMin,
        picTimeMinutes: picMin,
        landings: _form.landings,
        instructorName: _sanitise(_form.instructorName.text),
        isDayFlight: _form.isDayFlight,
      );

      final lessonId = await offlineLessons.createLesson(uid, lesson);

      // Upsert UserExercise for primary exercise
      await _upsertUserExercise(
        uid: uid,
        firestore: firestore,
        exerciseId: exerciseId,
        subExerciseId: subExerciseId,
        existingUE: existingUE,
        existingHistory: existingHistory,
      );

      // Upsert UserExercise for each additional exercise
      final allUEs = ref.read(userExercisesProvider).valueOrNull ?? [];
      for (final additionalComposite in _form.exerciseIds) {
        final (addExId, addSubId) = parseExerciseId(additionalComposite);
        final addUE = allUEs.where((ue) {
          return ue.exerciseId == addExId && ue.subExercise == addSubId;
        }).firstOrNull;
        await _upsertUserExercise(
          uid: uid,
          firestore: firestore,
          exerciseId: addExId,
          subExerciseId: addSubId,
          existingUE: addUE,
          existingHistory: addUE?.ratingHistory ?? [],
        );
      }

      // Increment hours_flown and stamp lastDebriefAt
      final userUpdate = <String, dynamic>{
        'last_debrief_at': FieldValue.serverTimestamp(),
      };
      if (durationMinutes != null && durationMinutes > 0) {
        userUpdate['hours_flown'] = FieldValue.increment(durationMinutes / 60);
      }
      await firestore.updateUser(uid, userUpdate);

      // Schedule spaced-rep notifications
      final exerciseName = exerciseFullName(widget.exerciseId);
      await NotificationService.scheduleSpacedRepetition(
        exerciseId: widget.exerciseId,
        exerciseName: exerciseName,
        completedAt: DateTime.now(),
        rating: _form.studentRating,
        ratingHistory: existingHistory,
      );

      for (final additionalComposite in _form.exerciseIds) {
        final addName = exerciseFullName(additionalComposite);
        final allUEsForNotif =
            ref.read(userExercisesProvider).valueOrNull ?? [];
        final (addExId, addSubId) = parseExerciseId(additionalComposite);
        final addUE = allUEsForNotif.where((ue) {
          return ue.exerciseId == addExId && ue.subExercise == addSubId;
        }).firstOrNull;
        await NotificationService.scheduleSpacedRepetition(
          exerciseId: additionalComposite,
          exerciseName: addName,
          completedAt: DateTime.now(),
          rating: _form.studentRating,
          ratingHistory: addUE?.ratingHistory ?? [],
        );
      }

      await NotificationService.scheduleInactivityReminder(DateTime.now());

      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_checked_in',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _form.studentRating,
          'duration_minutes': durationMinutes ?? 0,
        },
      );
      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_debriefed',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _form.studentRating,
          'lesson_type': lessonType.name,
        },
      );
      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_saved',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _form.studentRating,
        },
      );

      await _autosave.clearDraft(widget.exerciseId);
      RateAppService.instance.onLessonCompleted();

      if (mounted) {
        final savedOffline = lessonId.startsWith('local_');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(savedOffline
                ? 'Lesson saved offline \u2014 will sync when connected'
                : 'Lesson saved!'),
            backgroundColor: AppColors.success,
          ),
        );

        final latestUEs = ref.read(userExercisesProvider).valueOrNull ?? [];
        final allComplete = AppConstants.allExerciseIds.every((id) {
          return latestUEs.any((ue) {
            final composite = compositeExerciseId(ue.exerciseId, ue.subExercise);
            return composite == id && ue.status.isCompleted;
          });
        });

        if (exerciseId == 'ex_14') {
          context.go('/milestone', extra: {'firstSolo': true});
        } else if (allComplete) {
          context.go('/milestone', extra: {'firstSolo': false});
        } else {
          // Post-check-in → take the user straight into a conversational AI
          // debrief, prefilled with the lesson context they just logged.
          context.pushReplacement('/ask-ai', extra: _buildAiDebriefPrompt());
        }
      }

      // Fire-and-forget AI debrief \u2014 runs after navigation; errors must not
      // surface as a save failure.
      if (lessonType == LessonType.flight &&
          isOnline &&
          !lessonId.startsWith('local_')) {
        () async {
          try {
            final userIsPremium = await ref.read(premiumStatusProvider.future);
            if (!userIsPremium) return;
            FirebaseAnalytics.instance.logEvent(
              name: 'ai_debrief_requested',
              parameters: {'exercise_id': widget.exerciseId},
            );
            _callAiDebrief(
              uid: uid,
              lessonId: lessonId,
              firestore: firestore,
              exerciseName: exerciseFullName(widget.exerciseId),
              ratingHistory: existingHistory,
            );
            _callNextFocusAi(
              uid: uid,
              lessonId: lessonId,
              firestore: firestore,
              exerciseName: exerciseFullName(widget.exerciseId),
              existingUE: existingUE,
              existingHistory: existingHistory,
            );
          } catch (e, st) {
            FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
          }
        }();
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving lesson. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _sanitise(String text) => InputSanitiser.sanitise(
        text,
        maxLength: InputSanitiser.maxMedium,
      );

  /// Build a prefilled prompt for the conversational AI debrief from whatever
  /// the user has entered so far. Safe to call with empty form fields — those
  /// sections are simply omitted; the AI is capped at 2 follow-up questions.
  String _buildAiDebriefPrompt() {
    final reflection = _sanitise(_form.personalReflection.text);
    final instructorNotes = _sanitise(_form.instructorNotes.text);
    final exerciseName = exerciseFullName(widget.exerciseId);
    final durationMinutes = _form.flightHours * 60 + _form.flightMinutes;

    final buf = StringBuffer()
      ..write('I just finished a lesson on $exerciseName.\n\n')
      ..write('Lesson summary:\n')
      ..write('- Self rating: ${_form.studentRating}/5\n');

    if (_form.criterionRatings.isNotEmpty) {
      final criteria = ExerciseCriteria.forExercise(widget.exerciseId);
      final labelByKey = {for (final c in criteria) c.key: c.label};
      final parts = _form.criterionRatings.entries
          .map((e) => '${labelByKey[e.key] ?? e.key} ${e.value}/5')
          .join(', ');
      buf.write('- Skill ratings: $parts\n');
    }

    if (durationMinutes > 0) {
      buf.write('- Lesson duration: $durationMinutes min\n');
    }

    if (instructorNotes.isNotEmpty) {
      buf.write('- Instructor notes: "$instructorNotes"\n');
    }
    if (reflection.isNotEmpty) {
      buf.write('- My reflection: "$reflection"\n');
    }

    buf.write(
        '\nPlease debrief me — what went well, what to improve, and what to focus on next time. Use the lesson summary above and my training history to give the debrief directly. Only ask me a follow-up question if you genuinely need more information; otherwise just give the debrief. Maximum 2 questions if you do ask.');
    return buf.toString();
  }

  Future<void> _upsertUserExercise({
    required String uid,
    required FirestoreService firestore,
    required String exerciseId,
    required String? subExerciseId,
    required UserExercise? existingUE,
    required List<int> existingHistory,
  }) async {
    final newHistory = [...existingHistory, _form.studentRating];
    final bestRating = newHistory.reduce((a, b) => a > b ? a : b);
    final exerciseNum =
        existingUE?.exerciseNumber ?? _exerciseNumberFrom(exerciseId);

    await firestore.upsertUserExercise(
      uid,
      UserExercise(
        id: subExerciseId != null
            ? '${uid}_${exerciseId}_$subExerciseId'
            : '${uid}_$exerciseId',
        exerciseId: exerciseId,
        subExercise: subExerciseId,
        exerciseNumber: exerciseNum,
        status: _form.studentRating >= 3
            ? ExerciseStatus.completedSatisfactory
            : ExerciseStatus.completedUnsatisfactory,
        bestRating: bestRating,
        ratingHistory: newHistory,
        timesAttempted: (existingUE?.timesAttempted ?? 0) + 1,
        lastAttempted: DateTime.now(),
        spacedRepDue: DateTime.now().add(spacedRepDueOffsetForRating(_form.studentRating)),
        videoWatched: existingUE?.videoWatched ?? false,
        briefViewed: existingUE?.briefViewed ?? false,
        flashcardsCompleted: existingUE?.flashcardsCompleted ?? false,
        weatherChecked: existingUE?.weatherChecked ?? false,
        quizPassed: existingUE?.quizPassed ?? false,
        quizAttempted: existingUE?.quizAttempted ?? false,
        visualisationViewed: existingUE?.visualisationViewed ?? false,
      ),
    );
  }

  int _exerciseNumberFrom(String exerciseId) {
    final parts = exerciseId.split('_');
    if (parts.length >= 2) return int.tryParse(parts[1]) ?? 0;
    return 0;
  }

  Future<void> _callAiDebrief({
    required String uid,
    required String lessonId,
    required FirestoreService firestore,
    required String exerciseName,
    required List<int> ratingHistory,
  }) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable(
        'getAiDebrief',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final result = await callable.call({
        'exerciseId': widget.exerciseId,
        'lessonData': {
          'exerciseName': exerciseName,
          'studentRating': _form.studentRating,
          'instructorRating': null,
          'instructorNotes': _sanitise(_form.instructorNotes.text).isEmpty
              ? null
              : _sanitise(_form.instructorNotes.text),
          'personalReflection': _sanitise(_form.personalReflection.text).isEmpty
              ? null
              : _sanitise(_form.personalReflection.text),
          'quizScore': null,
          'ratingHistory': ratingHistory,
        },
      });
      final data = result.data as Map<dynamic, dynamic>;
      await firestore.updateLesson(uid, lessonId, {
        'ai_debrief_well': data['well'],
        'ai_debrief_improve': data['improve'],
        'ai_debrief_focus': data['focus'],
      });
      await FirebaseAnalytics.instance.logEvent(
        name: 'ai_debrief_generated',
        parameters: {'exercise_id': widget.exerciseId},
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      FirebaseAnalytics.instance.logEvent(
        name: 'ai_debrief_failed',
        parameters: {'exercise_id': widget.exerciseId},
      );
    }
  }

  Future<void> _callNextFocusAi({
    required String uid,
    required String lessonId,
    required FirestoreService firestore,
    required String exerciseName,
    required UserExercise? existingUE,
    required List<int> existingHistory,
  }) async {
    try {
      final criteria = ExerciseCriteria.forExercise(widget.exerciseId);
      final criterionLines = criteria
          .where((c) => _form.criterionRatings.containsKey(c.key))
          .map((c) => '- ${c.label}: ${_form.criterionRatings[c.key]}/5')
          .join('\n');

      final attemptCount = (existingUE?.timesAttempted ?? 0) + 1;
      final bestRating = existingHistory.isNotEmpty
          ? existingHistory.reduce((a, b) => a > b ? a : b)
          : null;

      final prompt = StringBuffer();
      prompt.writeln(
          'The student just completed a lesson on $exerciseName.');
      prompt.writeln('Overall rating: ${_form.studentRating}/5.');
      if (criterionLines.isNotEmpty) {
        prompt.writeln('Per-criterion ratings:');
        prompt.writeln(criterionLines);
      }
      prompt.writeln(
          'Previous sessions on this exercise: $attemptCount attempt${attemptCount == 1 ? '' : 's'}${bestRating != null ? ', previous best rating $bestRating/5' : ''}.');
      prompt.writeln(
          'Based on this, what is the single most important thing they should focus on in their next lesson? Keep your answer to 2–3 sentences. Be specific to the maneuver, not generic.');

      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable(
        'getAiDebrief',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 45)),
      );
      final result = await callable.call({
        'exerciseId': widget.exerciseId,
        'lessonData': {
          'exerciseName': exerciseName,
          'studentRating': _form.studentRating,
          'instructorNotes': _sanitise(_form.instructorNotes.text).isEmpty
              ? null
              : _sanitise(_form.instructorNotes.text),
          'personalReflection': _sanitise(_form.personalReflection.text).isEmpty
              ? null
              : _sanitise(_form.personalReflection.text),
          'criterionRatings': _form.criterionRatings.isNotEmpty
              ? _form.criterionRatings
              : null,
          'ratingHistory': existingHistory,
          'nextFocusPrompt': prompt.toString(),
        },
      });
      final data = result.data as Map<dynamic, dynamic>;
      final suggestion = (data['nextFocusSuggestion'] as String?) ??
          (data['focus'] as String?) ??
          '';
      if (suggestion.isNotEmpty) {
        await firestore.updateLesson(uid, lessonId, {
          'next_focus_suggestion': suggestion,
        });
      }
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) = parseExerciseId(widget.exerciseId);
    final uid = ref.watch(currentUserIdProvider);

    final nameKey = compositeExerciseId(exerciseId, subExerciseId);
    final exerciseName = exerciseCompactName(nameKey);

    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));
    final userExercisesAsync = ref.watch(userExercisesProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final canAccess = appUser?.canAccessExercise(widget.exerciseId) ??
        AppConstants.isFreeExercise(widget.exerciseId,
            currentExerciseNumber: appUser?.currentExerciseNumber ?? 1);

    if (!canAccess) {
      if (!_paywallLogged) {
        _paywallLogged = true;
        FirebaseAnalytics.instance.logEvent(
          name: 'paywall_shown',
          parameters: {
            'source': 'debrief',
            'exercise_id': widget.exerciseId,
          },
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lesson Check-In'),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: AppColors.primary, size: 48),
                const SizedBox(height: 20),
                Text(
                  'Pro Exercise',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upgrade to unlock lesson check-ins and\nAI-powered debriefs for all exercises.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => showPremiumPaywall(
                    context,
                    source: 'debrief',
                    freeWindowStart: appUser?.freeWindowStart ?? 1,
                    freeWindowEnd: appUser?.freeWindowEnd ?? 3,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Upgrade to Pro',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _isEditMode,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || _isEditMode) return;
        final hasContent = _form.instructorNotes.text.isNotEmpty ||
            _form.personalReflection.text.isNotEmpty;
        final navigator = Navigator.of(context);
        if (!hasContent) {
          navigator.pop();
          return;
        }
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Leave debrief?'),
            content: const Text(
                'Your draft is saved. You can resume next time you log a lesson for this exercise.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Keep filling in'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if ((leave ?? false) && mounted) navigator.pop();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Debrief' : 'Lesson Check-In'),
        elevation: 0,
        actions: [
          if (_draftSaved)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Draft saved',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: ConnectivityAwareBody(
        child: contentAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (e, _) => _buildForm(
            uid: uid,
            exerciseName: exerciseName,
            lessonType: LessonType.flight,
            existingUE: null,
            existingHistory: [],
          ),
          data: (content) {
            final lessonType = content?.lessonType ?? LessonType.flight;
            final existingUE = userExercisesAsync.valueOrNull?.where((ue) {
              return ue.exerciseId == exerciseId &&
                  ue.subExercise == subExerciseId;
            }).firstOrNull;
            return _buildForm(
              uid: uid,
              exerciseName: exerciseName,
              lessonType: lessonType,
              existingUE: existingUE,
              existingHistory: existingUE?.ratingHistory ?? [],
            );
          },
        ),
      ),
    ),
    );
  }

  Widget _buildForm({
    required String? uid,
    required String exerciseName,
    required LessonType lessonType,
    required UserExercise? existingUE,
    required List<int> existingHistory,
  }) {
    // Pre-fill aircraft type + last instructor on first build (data isn't
    // available during initState).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePrefillDefaults();
    });

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildHeader(exerciseName),
            const SizedBox(height: 24),

            LessonForm(
              controller: _form,
              mode: LessonFormMode.checkIn,
              primaryExerciseId: widget.exerciseId,
              lessonType: lessonType,
              onChanged: _onFieldChanged,
            ),
            const SizedBox(height: 16),

            // AI Debrief (secondary)
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/ask-ai',
                extra: _buildAiDebriefPrompt(),
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI Debrief'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(52),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Save
            ElevatedButton(
              onPressed: (_saving || uid == null)
                  ? null
                  : () => _save(
                        uid: uid,
                        lessonType: lessonType,
                        existingHistory: existingHistory,
                        existingUE: existingUE,
                      ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_isEditMode ? 'Update Debrief' : 'Save Lesson'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sub-widgets
  // ---------------------------------------------------------------------------

  Widget _buildHeader(String exerciseName) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          exerciseName,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Lesson Check-In',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

}

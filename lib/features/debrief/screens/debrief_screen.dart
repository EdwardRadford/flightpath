// Debrief screen — post-lesson form collecting ratings, reflections, and
// weather, then calling the Claude API for AI-generated feedback.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
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

  bool get _isEditMode => widget.existingLesson != null;

  int _studentRating = 3;
  final _instructorNotesController = TextEditingController();
  final _reflectionController = TextEditingController();
  final _soloDurationController = TextEditingController();
  bool _paywallLogged = false;

  // Duration
  int _durationHours = 1;
  int _durationMinutes = 0;
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;

  // Additional exercises covered in this lesson
  final Set<String> _additionalExerciseIds = {};

  bool _saving = false;

  // Autosave
  late final DebriefAutosaveService _autosave;

  @override
  void initState() {
    super.initState();
    _hoursController = TextEditingController(text: '1');
    _minutesController = TextEditingController(text: '00');
    _autosave = ref.read(debriefAutosaveServiceProvider);

    if (_isEditMode) {
      final lesson = widget.existingLesson!;
      _studentRating = lesson.studentRating ?? 3;
      _instructorNotesController.text = lesson.instructorNotes;
      _reflectionController.text = lesson.personalReflection;
      if (lesson.lessonDuration > 0) {
        _durationHours = lesson.lessonDuration ~/ 60;
        _durationMinutes = lesson.lessonDuration % 60;
        _hoursController.text = '$_durationHours';
        _minutesController.text =
            _durationMinutes.toString().padLeft(2, '0');
      }
      _additionalExerciseIds.addAll(lesson.additionalExerciseIds);
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

    _instructorNotesController.addListener(_onFieldChanged);
    _reflectionController.addListener(_onFieldChanged);
    _soloDurationController.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    _autosave.saveDraft(DebriefDraft(
      exerciseId: widget.exerciseId,
      studentRating: _studentRating,
      instructorNotes: _instructorNotesController.text,
      personalReflection: _reflectionController.text,
      soloDuration: _soloDurationController.text,
      durationHours: _durationHours,
      durationMinutes: _durationMinutes,
      additionalExerciseIds: _additionalExerciseIds.toList(),
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
      _studentRating = draft.studentRating;
      _instructorNotesController.text = draft.instructorNotes;
      _reflectionController.text = draft.personalReflection;
      _soloDurationController.text = draft.soloDuration;
      _durationHours = draft.durationHours;
      _durationMinutes = draft.durationMinutes;
      _hoursController.text = '${draft.durationHours}';
      _minutesController.text =
          draft.durationMinutes.toString().padLeft(2, '0');
      _additionalExerciseIds
        ..clear()
        ..addAll(draft.additionalExerciseIds);
    });
  }

  @override
  void dispose() {
    _instructorNotesController.removeListener(_onFieldChanged);
    _reflectionController.removeListener(_onFieldChanged);
    _soloDurationController.removeListener(_onFieldChanged);
    _instructorNotesController.dispose();
    _reflectionController.dispose();
    _soloDurationController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
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
          durationMinutes = _durationHours * 60 + _durationMinutes;
        } else if (lessonType == LessonType.milestone) {
          final text = _soloDurationController.text.trim();
          if (text.isNotEmpty) durationMinutes = int.tryParse(text);
        }

        final data = <String, dynamic>{
          'student_rating': _studentRating,
          'instructor_notes': _sanitise(_instructorNotesController.text).isEmpty
              ? null
              : _sanitise(_instructorNotesController.text),
          'personal_reflection': _sanitise(_reflectionController.text).isEmpty
              ? null
              : _sanitise(_reflectionController.text),
          if (durationMinutes != null) 'lesson_duration': durationMinutes,
          'additional_exercise_ids': _additionalExerciseIds.toList(),
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
        final text = _soloDurationController.text.trim();
        if (text.isNotEmpty) soloMinutes = int.tryParse(text);
      }

      int? durationMinutes;
      if (lessonType == LessonType.flight) {
        durationMinutes = _durationHours * 60 + _durationMinutes;
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

      final lesson = Lesson(
        id: '',
        exerciseId: exerciseId,
        subExercise: subExerciseId ?? '',
        studentRating: _studentRating,
        instructorRating: null,
        lessonDuration: durationMinutes ?? 0,
        instructorNotes: _sanitise(_instructorNotesController.text),
        personalReflection: _sanitise(_reflectionController.text),
        additionalExerciseIds: _additionalExerciseIds.toList(),
        lessonDate: DateTime.now(),
        status: LessonStatus.completed,
        createdAt: DateTime.now(),
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
      for (final additionalComposite in _additionalExerciseIds) {
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
        rating: _studentRating,
        ratingHistory: existingHistory,
      );

      for (final additionalComposite in _additionalExerciseIds) {
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
          rating: _studentRating,
          ratingHistory: addUE?.ratingHistory ?? [],
        );
      }

      await NotificationService.scheduleInactivityReminder(DateTime.now());

      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_checked_in',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _studentRating,
          'duration_minutes': durationMinutes ?? 0,
        },
      );
      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_debriefed',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _studentRating,
          'lesson_type': lessonType.name,
        },
      );
      FirebaseAnalytics.instance.logEvent(
        name: 'lesson_saved',
        parameters: {
          'exercise_id': widget.exerciseId,
          'rating': _studentRating,
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

        if (allComplete) {
          context.go('/completion');
        } else {
          context.go('/exercises');
        }
      }

      // Fire-and-forget AI debrief
      final userIsPremium =
          ref.read(appUserProvider).valueOrNull?.isPremium ?? false;
      if (lessonType == LessonType.flight &&
          userIsPremium &&
          isOnline &&
          !lessonId.startsWith('local_')) {
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

  Future<void> _upsertUserExercise({
    required String uid,
    required FirestoreService firestore,
    required String exerciseId,
    required String? subExerciseId,
    required UserExercise? existingUE,
    required List<int> existingHistory,
  }) async {
    final newHistory = [...existingHistory, _studentRating];
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
        status: _studentRating >= 3
            ? ExerciseStatus.completedSatisfactory
            : ExerciseStatus.completedUnsatisfactory,
        bestRating: bestRating,
        ratingHistory: newHistory,
        timesAttempted: (existingUE?.timesAttempted ?? 0) + 1,
        lastAttempted: DateTime.now(),
        spacedRepDue: DateTime.now().add(const Duration(days: 1)),
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
          'studentRating': _studentRating,
          'instructorRating': null,
          'instructorNotes': _sanitise(_instructorNotesController.text).isEmpty
              ? null
              : _sanitise(_instructorNotesController.text),
          'personalReflection': _sanitise(_reflectionController.text).isEmpty
              ? null
              : _sanitise(_reflectionController.text),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Debrief' : 'Lesson Check-In'),
        elevation: 0,
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
    );
  }

  Widget _buildForm({
    required String? uid,
    required String exerciseName,
    required LessonType lessonType,
    required UserExercise? existingUE,
    required List<int> existingHistory,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _buildHeader(exerciseName),
            const SizedBox(height: 28),

            // Self-rating
            _buildSectionLabel('How did the lesson go?'),
            const SizedBox(height: 12),
            _buildStarRating(
              rating: _studentRating,
              onChanged: (v) {
                setState(() => _studentRating = v);
                _onFieldChanged();
              },
            ),
            const SizedBox(height: 24),

            // Flight duration
            if (lessonType == LessonType.flight) ...[
              _buildSectionLabel('Flight Duration'),
              const SizedBox(height: 12),
              _buildDurationPicker(),
              const SizedBox(height: 24),
            ],

            // Solo duration (milestone)
            if (lessonType == LessonType.milestone) ...[
              _buildSectionLabel('Solo Flight Duration'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _soloDurationController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  labelText: 'Solo flight duration (minutes)',
                  suffixText: 'min',
                ),
                validator: (v) {
                  if (v != null && v.isNotEmpty) {
                    if (int.tryParse(v) == null) return 'Enter whole minutes';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            ],

            // Instructor comments (flight only)
            if (lessonType == LessonType.flight) ...[
              _buildSectionLabel("Instructor's Comments"),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructorNotesController,
                maxLines: 3,
                maxLength: InputSanitiser.maxMedium,
                style: TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  labelText: "Instructor's comments (optional)",
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Reflection
            if (lessonType != LessonType.milestone) ...[
              _buildSectionLabel('Your Reflection'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reflectionController,
                maxLines: 4,
                maxLength: InputSanitiser.maxMedium,
                style: TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  labelText: 'Your thoughts on the lesson (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Other exercises covered
            _buildSectionLabel('Other Exercises Covered'),
            const SizedBox(height: 6),
            Text(
              'Did this flight also practise any other exercises?',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 12),
            _buildAdditionalExercisesPicker(),
            const SizedBox(height: 28),

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

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStarRating({
    required int rating,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: () => onChanged(starIndex),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              starIndex <= rating
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: starIndex <= rating
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              size: 36,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDurationPicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _durationMinutes == 0
                ? '$_durationHours hr${_durationHours == 1 ? '' : 's'}'
                : '$_durationHours hr${_durationHours == 1 ? '' : 's'} $_durationMinutes min',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStepperField(
                  label: 'Hours',
                  controller: _hoursController,
                  value: _durationHours,
                  min: 0,
                  max: 8,
                  onDecrement: () {
                    if (_durationHours > 0) {
                      setState(() {
                        _durationHours--;
                        _hoursController.text = '$_durationHours';
                      });
                      _onFieldChanged();
                    }
                  },
                  onIncrement: () {
                    if (_durationHours < 8) {
                      setState(() {
                        _durationHours++;
                        _hoursController.text = '$_durationHours';
                      });
                      _onFieldChanged();
                    }
                  },
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0 && n <= 8) {
                      setState(() => _durationHours = n);
                      _onFieldChanged();
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStepperField(
                  label: 'Minutes',
                  controller: _minutesController,
                  value: _durationMinutes,
                  min: 0,
                  max: 59,
                  padded: true,
                  onDecrement: () {
                    if (_durationMinutes > 0) {
                      setState(() {
                        _durationMinutes--;
                        _minutesController.text =
                            _durationMinutes.toString().padLeft(2, '0');
                      });
                      _onFieldChanged();
                    }
                  },
                  onIncrement: () {
                    if (_durationMinutes < 59) {
                      setState(() {
                        _durationMinutes++;
                        _minutesController.text =
                            _durationMinutes.toString().padLeft(2, '0');
                      });
                      _onFieldChanged();
                    }
                  },
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0 && n <= 59) {
                      setState(() => _durationMinutes = n);
                      _onFieldChanged();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperField({
    required String label,
    required TextEditingController controller,
    required int value,
    required int min,
    required int max,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required ValueChanged<String> onChanged,
    bool padded = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.remove, size: 18),
                color: AppColors.onSurfaceVariant,
                onPressed: value > min ? onDecrement : null,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: onChanged,
                ),
              ),
              IconButton(
                icon: Icon(Icons.add, size: 18),
                color: AppColors.onSurfaceVariant,
                onPressed: value < max ? onIncrement : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalExercisesPicker() {
    final currentComposite = widget.exerciseId;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.allExerciseIds
          .where((id) => id != currentComposite)
          .map((id) {
        final selected = _additionalExerciseIds.contains(id);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (selected) {
                _additionalExerciseIds.remove(id);
              } else {
                _additionalExerciseIds.add(id);
              }
            });
            _onFieldChanged();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              exerciseCompactName(id),
              style: TextStyle(
                color:
                    selected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

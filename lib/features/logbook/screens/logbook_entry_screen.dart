// Manual logbook entry screen — uses the shared [LessonForm] so the field
// set is identical to the post-lesson Check-In flow. Differences in this
// mode: there is no preset primary exercise (the user picks every exercise
// covered), and saving returns to the logbook (no AI redirect).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/features/lesson_log/widgets/lesson_form.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/offline_lesson_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/connectivity_banner.dart';

/// Manual logbook entry / edit screen.
///
/// When [existingLesson] is non-null the form is in edit mode — fields are
/// pre-filled from the lesson document and saving updates in place. Older
/// lessons that pre-date the 2026-04-29 logbook-field migration simply have
/// empty strings / zero values, which the form treats as "not set".
class LogbookEntryScreen extends ConsumerStatefulWidget {
  final Lesson? existingLesson;

  const LogbookEntryScreen({super.key, this.existingLesson});

  @override
  ConsumerState<LogbookEntryScreen> createState() => _LogbookEntryScreenState();
}

class _LogbookEntryScreenState extends ConsumerState<LogbookEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LessonFormController _form;
  bool _saving = false;
  bool _prefilled = false;

  bool get _isEditMode => widget.existingLesson != null;

  @override
  void initState() {
    super.initState();
    _form = LessonFormController(flightHours: 0);

    if (_isEditMode) {
      final lesson = widget.existingLesson!;
      _form.lessonDate = lesson.lessonDate ?? DateTime.now();
      _form.studentRating = lesson.studentRating ?? 3;
      _form.instructorNotes.text = lesson.instructorNotes;
      _form.personalReflection.text = lesson.personalReflection;
      _form.aircraftType = lesson.aircraftType;
      _form.registration.text = lesson.aircraftRegistration;
      _form.departureIcao.text = lesson.departureAirfield;
      _form.arrivalIcao.text = lesson.arrivalAirfield;
      _form.landings = lesson.landings;
      _form.instructorName.text = lesson.instructorName;
      _form.remarks.text = lesson.remarks;
      _form.isDayFlight = lesson.isDayFlight;
      if (lesson.lessonDuration > 0) {
        _form.flightHours = lesson.lessonDuration ~/ 60;
        _form.flightMinutes = lesson.lessonDuration % 60;
      }
      if (lesson.exerciseId.isNotEmpty) {
        _form.exerciseIds.add(lesson.exerciseId);
      }
      if (lesson.picTimeMinutes > 0 && lesson.dualTimeMinutes == 0) {
        _form.pilotRole = PilotRole.pic;
      }
      _prefilled = true;
    }
  }

  /// Pre-fill aircraft type and last instructor on first build for new
  /// entries.
  void _maybePrefillDefaults() {
    if (_prefilled) return;
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
    _prefilled = true;
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final totalMinutes = _form.flightTimeMinutes;
    final dualMinutes =
        _form.pilotRole == PilotRole.dual ? totalMinutes : 0;
    final picMinutes = _form.pilotRole == PilotRole.pic ? totalMinutes : 0;

    if (totalMinutes > 8 * 60 + 59) {
      _showError('Maximum flight time is 8h 59m.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Pick the first selected exercise as the primary, or fall back to
      // 'ex_01' if the user picked nothing. Subsequent exercises ride along
      // as additionals (matching the check-in flow).
      final selected = _form.exerciseIds.toList();
      final primary = selected.isNotEmpty ? selected.first : 'ex_01';
      final additionals =
          selected.length > 1 ? selected.sublist(1) : <String>[];

      if (_isEditMode) {
        final data = <String, dynamic>{
          'lesson_date': _form.lessonDate,
          'student_rating': _form.studentRating,
          'instructor_notes': _sanitise(_form.instructorNotes.text),
          'personal_reflection': _sanitise(_form.personalReflection.text),
          'lesson_duration': totalMinutes,
          'flight_time_minutes': totalMinutes,
          'dual_time_minutes': dualMinutes,
          'pic_time_minutes': picMinutes,
          'landings': _form.landings,
          'aircraft_type': _form.aircraftType,
          'aircraft_registration':
              _form.registration.text.trim().toUpperCase(),
          'departure_airfield':
              _form.departureIcao.text.trim().toUpperCase(),
          'arrival_airfield': _form.arrivalIcao.text.trim().toUpperCase(),
          'instructor_name': _sanitise(_form.instructorName.text),
          'remarks': _sanitise(_form.remarks.text),
          'is_day_flight': _form.isDayFlight,
          'additional_exercise_ids': additionals,
        };
        await ref
            .read(offlineLessonServiceProvider)
            .updateLesson(uid, widget.existingLesson!.id, data);
      } else {
        final lesson = Lesson(
          id: '',
          exerciseId: primary,
          lessonDate: _form.lessonDate,
          lessonDuration: totalMinutes,
          status: LessonStatus.manualEntry,
          createdAt: DateTime.now(),
          studentRating: _form.studentRating,
          instructorNotes: _sanitise(_form.instructorNotes.text),
          personalReflection: _sanitise(_form.personalReflection.text),
          additionalExerciseIds: additionals,
          aircraftType: _form.aircraftType,
          aircraftRegistration:
              _form.registration.text.trim().toUpperCase(),
          departureAirfield:
              _form.departureIcao.text.trim().toUpperCase(),
          arrivalAirfield: _form.arrivalIcao.text.trim().toUpperCase(),
          flightTimeMinutes: totalMinutes,
          dualTimeMinutes: dualMinutes,
          picTimeMinutes: picMinutes,
          landings: _form.landings,
          instructorName: _sanitise(_form.instructorName.text),
          remarks: _sanitise(_form.remarks.text),
          isDayFlight: _form.isDayFlight,
        );

        await ref.read(offlineLessonServiceProvider).createLesson(uid, lesson);
      }

      FirebaseAnalytics.instance.logEvent(
        name: _isEditMode
            ? 'logbook_manual_entry_updated'
            : 'logbook_manual_entry_added',
        parameters: {'exercise_id': primary},
      );

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode ? 'Entry updated' : 'Logbook entry added'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e, st) {
      FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
      _showError('Failed to save entry. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _sanitise(String text) =>
      InputSanitiser.sanitise(text, maxLength: InputSanitiser.maxMedium);

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePrefillDefaults();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Logbook Entry' : 'New Logbook Entry'),
        elevation: 0,
      ),
      body: ConnectivityAwareBody(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                LessonForm(
                  controller: _form,
                  mode: LessonFormMode.newEntry,
                  showCriterionRatings: false,
                ),
                const SizedBox(height: 16),

                // AI Debrief (secondary) — same affordance as check-in so the
                // user can still get a conversational debrief on a manual log.
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

                // Save button
                ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditMode ? 'Update Entry' : 'Save Entry',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the AI debrief prompt from the form state — same shape as the
  /// post-lesson check-in version so the conversation feels consistent
  /// regardless of entry route.
  String _buildAiDebriefPrompt() {
    final reflection = _sanitise(_form.personalReflection.text);
    final instructorNotes = _sanitise(_form.instructorNotes.text);

    final buf = StringBuffer()..write('I just logged a flight in my logbook.\n\n');
    buf.write('Lesson summary:\n');
    buf.write('- Self rating: ${_form.studentRating}/5\n');
    if (_form.flightTimeMinutes > 0) {
      buf.write('- Flight time: ${_form.flightTimeMinutes} min\n');
    }
    if (_form.exerciseIds.isNotEmpty) {
      buf.write('- Exercises: ${_form.exerciseIds.join(", ")}\n');
    }
    if (instructorNotes.isNotEmpty) {
      buf.write('- Instructor notes: "$instructorNotes"\n');
    }
    if (reflection.isNotEmpty) {
      buf.write('- My reflection: "$reflection"\n');
    }
    buf.write(
        '\nPlease debrief me — what went well, what to improve, and what to focus on next time. You may ask me at most 2 short follow-up questions to fill in gaps; do not ask more.');
    return buf.toString();
  }
}

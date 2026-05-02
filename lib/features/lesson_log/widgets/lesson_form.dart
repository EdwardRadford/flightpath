// Shared lesson form — used by both the post-lesson Check-In flow
// (DebriefScreen) and the manual New Logbook Entry flow (LogbookEntryScreen).
//
// In Check-In mode (`LessonFormMode.checkIn`) the form has a primary exercise
// pre-set by the route and asks "which other exercises did you also cover?".
// In New Logbook Entry mode (`LessonFormMode.newEntry`) there is no preset and
// the user picks every exercise covered in a single multi-select.
//
// All field state is owned by [LessonFormController] which the parent screen
// constructs and keeps in its own state. The screen reads values from the
// controller when saving and writes initial values into it on load.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/exercise_criteria.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/tools/data/airfield_data.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

/// Which surface is hosting this form.
enum LessonFormMode {
  /// Post-lesson check-in. A primary `exerciseId` is preset by the route;
  /// the multi-select asks for OTHER exercises covered in the same flight.
  checkIn,

  /// Manual logbook entry. No preset; the user picks every exercise covered.
  newEntry,
}

/// Pilot-in-command status for the flight.
enum PilotRole {
  /// Dual instruction with an instructor.
  dual,

  /// Pilot in command (post-solo).
  pic,

  /// Pilot under training (solo flight that still counts toward training).
  put,
}

/// Holds every editable field on the [LessonForm].
///
/// Construct in the parent screen's state, dispose in `dispose()`. The form
/// widget calls back via [onChanged] whenever any field mutates so the parent
/// can drive autosave or validation.
class LessonFormController {
  // ── Date ──────────────────────────────────────────────────────────────────
  DateTime lessonDate;

  // ── Day / night ───────────────────────────────────────────────────────────
  bool isDayFlight;

  // ── Aircraft ──────────────────────────────────────────────────────────────
  String aircraftType; // key into AppConstants.aircraftTypes
  final TextEditingController registration;

  // ── Airfields ─────────────────────────────────────────────────────────────
  final TextEditingController departureIcao;
  final TextEditingController arrivalIcao;

  // ── Time fields (minutes) ─────────────────────────────────────────────────
  int flightHours;
  int flightMinutes;

  /// Pilot role determines whether [flightTimeMinutes] is logged as dual,
  /// PIC or P/UT time on the resulting [Lesson].
  PilotRole pilotRole;

  /// Landings in this lesson. Min 0.
  int landings;

  // ── Ratings + reflection ──────────────────────────────────────────────────
  int studentRating;
  final Map<String, int> criterionRatings;

  final TextEditingController instructorNotes;
  final TextEditingController personalReflection;
  final TextEditingController instructorName;
  final TextEditingController remarks;

  // ── Exercises ─────────────────────────────────────────────────────────────
  /// In `checkIn` mode this is "additional" exercises beyond the preset
  /// primary. In `newEntry` mode this holds every exercise covered.
  final Set<String> exerciseIds;

  /// Used in newEntry mode when the user picks "Custom / Other".
  String selectedExercise;
  final TextEditingController customExerciseName;

  /// Solo / milestone duration text (only used in checkIn mode for milestone
  /// lesson types).
  final TextEditingController soloDuration;

  LessonFormController({
    DateTime? lessonDate,
    this.isDayFlight = true,
    this.aircraftType = '',
    String registration = '',
    String departureIcao = '',
    String arrivalIcao = '',
    this.flightHours = 1,
    this.flightMinutes = 0,
    this.pilotRole = PilotRole.put,
    this.landings = 1,
    this.studentRating = 3,
    Map<String, int>? criterionRatings,
    String instructorNotes = '',
    String personalReflection = '',
    String instructorName = '',
    String remarks = '',
    Set<String>? exerciseIds,
    this.selectedExercise = 'ex_01',
    String customExerciseName = '',
    String soloDuration = '',
  })  : lessonDate = lessonDate ?? DateTime.now(),
        registration = TextEditingController(text: registration),
        departureIcao = TextEditingController(text: departureIcao),
        arrivalIcao = TextEditingController(text: arrivalIcao),
        instructorNotes = TextEditingController(text: instructorNotes),
        personalReflection = TextEditingController(text: personalReflection),
        instructorName = TextEditingController(text: instructorName),
        remarks = TextEditingController(text: remarks),
        customExerciseName = TextEditingController(text: customExerciseName),
        soloDuration = TextEditingController(text: soloDuration),
        criterionRatings = criterionRatings ?? <String, int>{},
        exerciseIds = exerciseIds ?? <String>{};

  int get flightTimeMinutes => flightHours * 60 + flightMinutes;

  void dispose() {
    registration.dispose();
    departureIcao.dispose();
    arrivalIcao.dispose();
    instructorNotes.dispose();
    personalReflection.dispose();
    instructorName.dispose();
    remarks.dispose();
    customExerciseName.dispose();
    soloDuration.dispose();
  }
}

/// Shared lesson form widget rendered inside both screens.
class LessonForm extends ConsumerStatefulWidget {
  final LessonFormController controller;
  final LessonFormMode mode;

  /// In `checkIn` mode this is the primary exercise the user is checking in
  /// against (pre-set by the route, e.g. "ex_07"). In `newEntry` mode it is
  /// ignored and the user picks the exercise via a dropdown.
  final String? primaryExerciseId;

  /// Lesson type for the primary exercise (flight / milestone / etc.) — only
  /// used in `checkIn` mode to drive the duration / solo-duration UX.
  final LessonType lessonType;

  /// Called whenever any field changes so the parent can run autosave.
  final VoidCallback? onChanged;

  /// Whether to render the per-criterion rating chips. Set to false when the
  /// host screen has its own ratings UI (newEntry currently has none).
  final bool showCriterionRatings;

  const LessonForm({
    super.key,
    required this.controller,
    required this.mode,
    this.primaryExerciseId,
    this.lessonType = LessonType.flight,
    this.onChanged,
    this.showCriterionRatings = true,
  });

  @override
  ConsumerState<LessonForm> createState() => _LessonFormState();
}

class _LessonFormState extends ConsumerState<LessonForm> {
  LessonFormController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.registration.addListener(_emitChange);
    c.departureIcao.addListener(_emitChange);
    c.arrivalIcao.addListener(_emitChange);
    c.instructorNotes.addListener(_emitChange);
    c.personalReflection.addListener(_emitChange);
    c.instructorName.addListener(_emitChange);
    c.remarks.addListener(_emitChange);
    c.customExerciseName.addListener(_emitChange);
    c.soloDuration.addListener(_emitChange);
  }

  @override
  void dispose() {
    c.registration.removeListener(_emitChange);
    c.departureIcao.removeListener(_emitChange);
    c.arrivalIcao.removeListener(_emitChange);
    c.instructorNotes.removeListener(_emitChange);
    c.personalReflection.removeListener(_emitChange);
    c.instructorName.removeListener(_emitChange);
    c.remarks.removeListener(_emitChange);
    c.customExerciseName.removeListener(_emitChange);
    c.soloDuration.removeListener(_emitChange);
    super.dispose();
  }

  void _emitChange() => widget.onChanged?.call();

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.mode == LessonFormMode.checkIn;
    final lessonType = widget.lessonType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Date (newEntry only — checkIn is always "today") ────────────────
        if (!isCheckIn) ...[
          _SectionLabel('Date'),
          const SizedBox(height: 8),
          _DatePickerTile(
            date: c.lessonDate,
            onPick: (picked) {
              setState(() => c.lessonDate = picked);
              _emitChange();
            },
          ),
          const SizedBox(height: 20),
        ],

        // ── Day / night ─────────────────────────────────────────────────────
        Row(
          children: [
            _SectionLabel('Day / Night'),
            const Spacer(),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Day')),
                ButtonSegment(value: false, label: Text('Night')),
              ],
              selected: {c.isDayFlight},
              onSelectionChanged: (v) {
                setState(() => c.isDayFlight = v.first);
                _emitChange();
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.2),
                selectedForegroundColor: AppColors.primary,
                foregroundColor: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Aircraft type ───────────────────────────────────────────────────
        _SectionLabel('Aircraft'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: c.aircraftType.isEmpty ? null : c.aircraftType,
          decoration: InputDecoration(
            hintText: 'Select aircraft type',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          dropdownColor: AppColors.surfaceVariant,
          isExpanded: true,
          items: AppConstants.aircraftTypes.entries
              .map(
                (e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(
                    e.value,
                    style: TextStyle(color: AppColors.onSurface),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            setState(() => c.aircraftType = v ?? '');
            _emitChange();
          },
        ),
        const SizedBox(height: 12),

        // ── Aircraft registration ───────────────────────────────────────────
        TextFormField(
          controller: c.registration,
          textCapitalization: TextCapitalization.characters,
          style: TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Registration (optional)',
            hintText: 'e.g. G-BXYZ',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),

        // ── Departure + arrival ICAO ────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Departure'),
                  const SizedBox(height: 8),
                  _IcaoAutocomplete(
                    controller: c.departureIcao,
                    hint: 'EGTC',
                    onChanged: _emitChange,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Arrival'),
                  const SizedBox(height: 8),
                  _IcaoAutocomplete(
                    controller: c.arrivalIcao,
                    hint: 'EGTC',
                    onChanged: _emitChange,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Flight duration ─────────────────────────────────────────────────
        if (lessonType != LessonType.milestone || !isCheckIn) ...[
          _SectionLabel('Flight Time'),
          const SizedBox(height: 8),
          _TimePickerRow(
            hours: c.flightHours,
            minutes: c.flightMinutes,
            onChanged: (h, m) {
              setState(() {
                c.flightHours = h;
                c.flightMinutes = m;
              });
              _emitChange();
            },
          ),
          const SizedBox(height: 20),
        ],

        // ── Solo duration (checkIn + milestone) ─────────────────────────────
        if (isCheckIn && lessonType == LessonType.milestone) ...[
          _SectionLabel('Solo Flight Duration'),
          const SizedBox(height: 8),
          TextFormField(
            controller: c.soloDuration,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: 'Solo flight duration (minutes)',
              suffixText: 'min',
            ),
            validator: (v) {
              if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                return 'Enter whole minutes';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
        ],

        // ── Pilot role (dual / PIC / P/UT) ──────────────────────────────────
        _SectionLabel('Time Logged As'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _RoleChip(
              label: 'Dual',
              selected: c.pilotRole == PilotRole.dual,
              onTap: () {
                setState(() => c.pilotRole = PilotRole.dual);
                _emitChange();
              },
            ),
            _RoleChip(
              label: 'P1 (PIC)',
              selected: c.pilotRole == PilotRole.pic,
              onTap: () {
                setState(() => c.pilotRole = PilotRole.pic);
                _emitChange();
              },
            ),
            _RoleChip(
              label: 'P/UT',
              selected: c.pilotRole == PilotRole.put,
              onTap: () {
                setState(() => c.pilotRole = PilotRole.put);
                _emitChange();
              },
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Landings ────────────────────────────────────────────────────────
        _SectionLabel('Landings'),
        const SizedBox(height: 8),
        Row(
          children: [
            _CounterButton(
              icon: Icons.remove_rounded,
              onTap: () {
                if (c.landings > 0) {
                  setState(() => c.landings--);
                  _emitChange();
                }
              },
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 50,
              child: Text(
                '${c.landings}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 14),
            _CounterButton(
              icon: Icons.add_rounded,
              onTap: () {
                setState(() => c.landings++);
                _emitChange();
              },
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Self rating ─────────────────────────────────────────────────────
        _SectionLabel('How did the lesson go?'),
        const SizedBox(height: 12),
        _StarRating(
          rating: c.studentRating,
          onChanged: (v) {
            setState(() => c.studentRating = v);
            _emitChange();
          },
        ),
        const SizedBox(height: 24),

        // ── Per-criterion ratings (checkIn only, primary exercise) ──────────
        if (widget.showCriterionRatings &&
            isCheckIn &&
            widget.primaryExerciseId != null)
          _CriterionRatings(
            exerciseId: widget.primaryExerciseId!,
            ratings: c.criterionRatings,
            onChanged: (key, value) {
              setState(() {
                if (value == null) {
                  c.criterionRatings.remove(key);
                } else {
                  c.criterionRatings[key] = value;
                }
              });
              _emitChange();
            },
          ),

        // ── Instructor name ─────────────────────────────────────────────────
        _SectionLabel('Instructor'),
        const SizedBox(height: 8),
        TextFormField(
          controller: c.instructorName,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            labelText: 'Instructor name (optional)',
            hintText: 'e.g. John Smith',
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),

        // ── Instructor's comments (flight only) ─────────────────────────────
        if (lessonType == LessonType.flight) ...[
          _SectionLabel("Instructor's Comments"),
          const SizedBox(height: 8),
          TextFormField(
            controller: c.instructorNotes,
            maxLines: 3,
            maxLength: InputSanitiser.maxMedium,
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: "Instructor's comments (optional)",
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Personal reflection ─────────────────────────────────────────────
        if (lessonType != LessonType.milestone) ...[
          _SectionLabel('Your Reflection'),
          const SizedBox(height: 8),
          TextFormField(
            controller: c.personalReflection,
            maxLines: 4,
            maxLength: InputSanitiser.maxMedium,
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: 'Your thoughts on the lesson (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Exercises covered ───────────────────────────────────────────────
        if (isCheckIn) ...[
          _SectionLabel('Other Exercises Covered'),
          const SizedBox(height: 6),
          Text(
            'Did this flight also practise any other exercises?',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _ExerciseChipsMulti(
            selectedIds: c.exerciseIds,
            excludeId: widget.primaryExerciseId,
            onToggle: (id) {
              setState(() {
                if (c.exerciseIds.contains(id)) {
                  c.exerciseIds.remove(id);
                } else {
                  c.exerciseIds.add(id);
                }
              });
              _emitChange();
            },
          ),
        ] else ...[
          _SectionLabel('Exercises Covered'),
          const SizedBox(height: 6),
          Text(
            'Tap every exercise covered in this flight.',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _ExerciseChipsMulti(
            selectedIds: c.exerciseIds,
            excludeId: null,
            onToggle: (id) {
              setState(() {
                if (c.exerciseIds.contains(id)) {
                  c.exerciseIds.remove(id);
                } else {
                  c.exerciseIds.add(id);
                }
              });
              _emitChange();
            },
          ),
        ],
        const SizedBox(height: 20),

        // ── Remarks (newEntry only) ─────────────────────────────────────────
        if (!isCheckIn) ...[
          _SectionLabel('Remarks'),
          const SizedBox(height: 8),
          TextFormField(
            controller: c.remarks,
            maxLines: 3,
            maxLength: InputSanitiser.maxMedium,
            style: TextStyle(color: AppColors.onSurface),
            decoration: InputDecoration(
              labelText: 'Optional notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

// ===========================================================================
// Sub-widgets
// ===========================================================================

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  const _DatePickerTile({required this.date, required this.onPick});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: brightness == Brightness.dark
                ? const ColorScheme.dark(
                    primary: AppColors.primary,
                    surface: AppColors.surfaceDark,
                    onSurface: AppColors.onSurfaceDark,
                  )
                : const ColorScheme.light(
                    primary: AppColors.primary,
                    surface: AppColors.surfaceLight,
                    onSurface: AppColors.onSurfaceLight,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) onPick(picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _pick(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              color: AppColors.onSurfaceVariant,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              DateFormat('EEE, d MMMM yyyy').format(date),
              style: TextStyle(color: AppColors.onSurface, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _IcaoAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onChanged;

  const _IcaoAutocomplete({
    required this.controller,
    required this.hint,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textValue) {
        final query = textValue.text.trim().toUpperCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return kAirfields
            .where((a) =>
                a.icao.toUpperCase().contains(query) ||
                a.name.toUpperCase().contains(query))
            .map((a) => '${a.icao} — ${a.name}')
            .take(8);
      },
      displayStringForOption: (option) {
        // Strip the human-readable part on selection so the field stores the
        // ICAO only.
        final dash = option.indexOf(' — ');
        return dash > 0 ? option.substring(0, dash) : option;
      },
      onSelected: (option) {
        final dash = option.indexOf(' — ');
        controller.text = (dash > 0 ? option.substring(0, dash) : option)
            .toUpperCase();
        onChanged?.call();
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        // Sync the autocomplete's controller back to ours so saves see the
        // latest free-text value too (some students fly from grass strips
        // not in the catalogue).
        if (fieldController.text != controller.text) {
          fieldController.text = controller.text;
          fieldController.selection = TextSelection.collapsed(
            offset: fieldController.text.length,
          );
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            LengthLimitingTextInputFormatter(4),
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
          ],
          style: TextStyle(color: AppColors.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.onSurfaceVariant),
          ),
          onChanged: (value) {
            controller.text = value.toUpperCase();
            onChanged?.call();
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Text(
                        option,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TimePickerRow extends StatelessWidget {
  final int hours;
  final int minutes;
  final void Function(int hours, int minutes) onChanged;

  const _TimePickerRow({
    required this.hours,
    required this.minutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: DropdownButtonFormField<int>(
            initialValue: hours,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            dropdownColor: AppColors.surfaceVariant,
            items: List.generate(
              9,
              (i) => DropdownMenuItem(
                value: i,
                child: Text(
                  '$i h',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ),
            ),
            onChanged: (v) => onChanged(v ?? 0, minutes),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: DropdownButtonFormField<int>(
            initialValue: minutes,
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            dropdownColor: AppColors.surfaceVariant,
            items: List.generate(
              60,
              (i) => DropdownMenuItem(
                value: i,
                child: Text(
                  '${i.toString().padLeft(2, '0')} m',
                  style: TextStyle(color: AppColors.onSurface),
                ),
              ),
            ),
            onChanged: (v) => onChanged(hours, v ?? 0),
          ),
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RoleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CounterButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.onSurface, size: 22),
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  final int rating;
  final ValueChanged<int> onChanged;

  const _StarRating({required this.rating, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Rating: $rating of 5 stars',
          slider: true,
          value: '$rating',
          child: Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return Semantics(
                button: true,
                label: 'Set rating to $starIndex',
                child: ExcludeSemantics(
                  child: GestureDetector(
                    onTap: () => onChanged(starIndex),
                    child: Padding(
                      // Pad each star to a 44pt+ tap target.
                      padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
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
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Struggled',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
            Text(
              'Nailed it',
              style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

/// Per-criterion 1-5 rating dots — only rendered for the primary exercise in
/// check-in mode, since CAA criteria are per-exercise.
class _CriterionRatings extends ConsumerWidget {
  final String exerciseId;
  final Map<String, int> ratings;
  final void Function(String key, int? value) onChanged;

  const _CriterionRatings({
    required this.exerciseId,
    required this.ratings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lazy import to avoid a circular dep — exercise_criteria has no riverpod
    // deps so it's safe.
    final criteriaList = _criteriaFor(exerciseId);
    if (criteriaList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate each skill',
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'CAA assessment criteria — rate how you feel each went (optional)',
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 13),
        ),
        const SizedBox(height: 12),
        ...criteriaList.map((criterion) {
          final current = ratings[criterion.$1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.$2,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: List.generate(5, (index) {
                    final dotIndex = index + 1;
                    final filled = current != null && dotIndex <= current;
                    return GestureDetector(
                      onTap: () {
                        if (current == dotIndex) {
                          onChanged(criterion.$1, null);
                        } else {
                          onChanged(criterion.$1, dotIndex);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: filled
                                ? AppColors.primary
                                : AppColors.primary.withValues(alpha: 0.12),
                            border: Border.all(
                              color: filled
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$dotIndex',
                              style: TextStyle(
                                color: filled
                                    ? Colors.white
                                    : AppColors.onSurfaceVariant,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  // (key, label) pairs for each criterion.
  List<(String, String)> _criteriaFor(String exerciseId) {
    return ExerciseCriteria.forExercise(exerciseId)
        .map((c) => (c.key, c.label))
        .toList();
  }
}

/// Multi-select chip grid for picking exercises.
class _ExerciseChipsMulti extends StatelessWidget {
  final Set<String> selectedIds;
  final String? excludeId;
  final ValueChanged<String> onToggle;

  const _ExerciseChipsMulti({
    required this.selectedIds,
    required this.excludeId,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.allExerciseIds
          .where((id) => id != excludeId)
          .map((id) {
        final selected = selectedIds.contains(id);
        return GestureDetector(
          onTap: () => onToggle(id),
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
                color: selected
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

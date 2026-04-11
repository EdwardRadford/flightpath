// Manual logbook entry screen — allows adding logbook entries for flights
// done before the app or flights not linked to an exercise.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/offline_lesson_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/shared/widgets/connectivity_banner.dart';

class LogbookEntryScreen extends ConsumerStatefulWidget {
  const LogbookEntryScreen({super.key});

  @override
  ConsumerState<LogbookEntryScreen> createState() => _LogbookEntryScreenState();
}

class _LogbookEntryScreenState extends ConsumerState<LogbookEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  // Form values
  DateTime _date = DateTime.now();
  String _aircraftType = '';
  final _regController = TextEditingController();
  final _departureController = TextEditingController();
  final _arrivalController = TextEditingController();
  int _flightHours = 0;
  int _flightMinutes = 0;
  int _dualHours = 0;
  int _dualMinutes = 0;
  int _picHours = 0;
  int _picMinutes = 0;
  final _landingsController = TextEditingController();
  final _instructorController = TextEditingController();
  final _remarksController = TextEditingController();
  final _customExerciseController = TextEditingController();
  bool _isDayFlight = true;
  String _selectedExercise = 'ex_01';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user != null && user.aircraftType.isNotEmpty) {
        setState(() => _aircraftType = user.aircraftType);
      }
      if (user != null && user.airfieldIcao.isNotEmpty) {
        _departureController.text = user.airfieldIcao.toUpperCase();
        _arrivalController.text = user.airfieldIcao.toUpperCase();
      }
    });
  }

  @override
  void dispose() {
    _regController.dispose();
    _departureController.dispose();
    _arrivalController.dispose();
    _landingsController.dispose();
    _instructorController.dispose();
    _remarksController.dispose();
    _customExerciseController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
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
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final totalMinutes = _flightHours * 60 + _flightMinutes;
    final dualMinutes = _dualHours * 60 + _dualMinutes;
    final picMinutes = _picHours * 60 + _picMinutes;
    final landings = int.tryParse(_landingsController.text) ?? 0;

    // Validate: PIC + dual should not exceed flight time
    if (totalMinutes > 0 && (dualMinutes + picMinutes) > totalMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Dual + PIC time cannot exceed total flight time.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // Validate: max flight time 8h 59m
    if (totalMinutes > 8 * 60 + 59) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum flight time is 8h 59m.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (landings < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Landings cannot be negative.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final lesson = Lesson(
        id: '',
        exerciseId: _selectedExercise == 'custom' ? 'ex_01' : _selectedExercise,
        lessonDate: _date,
        lessonDuration: totalMinutes > 0 ? totalMinutes : 0,
        status: LessonStatus.manualEntry,
        createdAt: DateTime.now(),
        aircraftRegistration: InputSanitiser.sanitise(
          _regController.text.toUpperCase(),
          maxLength: 20,
        ),
        aircraftType: _aircraftType,
        departureAirfield: InputSanitiser.sanitise(
          _departureController.text.toUpperCase(),
          maxLength: 4,
        ),
        arrivalAirfield: InputSanitiser.sanitise(
          _arrivalController.text.toUpperCase(),
          maxLength: 4,
        ),
        flightTimeMinutes: totalMinutes > 0 ? totalMinutes : 0,
        dualTimeMinutes: dualMinutes > 0 ? dualMinutes : 0,
        picTimeMinutes: picMinutes > 0 ? picMinutes : 0,
        landings: landings > 0 ? landings : 0,
        instructorName: InputSanitiser.sanitise(
          _instructorController.text,
          maxLength: InputSanitiser.maxName,
        ),
        remarks: InputSanitiser.sanitise(
          _remarksController.text,
          maxLength: InputSanitiser.maxMedium,
        ),
        isDayFlight: _isDayFlight,
        customExerciseName: _selectedExercise == 'custom'
            ? InputSanitiser.sanitise(
                _customExerciseController.text,
                maxLength: InputSanitiser.maxName,
              )
            : '',
      );

      final offlineLessons = ref.read(offlineLessonServiceProvider);
      await offlineLessons.createLesson(uid, lesson);

      FirebaseAnalytics.instance.logEvent(
        name: 'logbook_manual_entry_added',
        parameters: {'exercise_id': _selectedExercise},
      );

      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Logbook entry added'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to save entry. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Logbook Entry'),
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
                // Date picker
                const _SectionLabel(label: 'Date'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            color: AppColors.onSurfaceVariant, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('EEE, d MMMM yyyy').format(_date),
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Day / Night toggle
                Row(
                  children: [
                    const _SectionLabel(label: 'Day/Night'),
                    const Spacer(),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Day')),
                        ButtonSegment(value: false, label: Text('Night')),
                      ],
                      selected: {_isDayFlight},
                      onSelectionChanged: (v) =>
                          setState(() => _isDayFlight = v.first),
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

                // Aircraft type
                const _SectionLabel(label: 'Aircraft Type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _aircraftType.isEmpty ? null : _aircraftType,
                  decoration: InputDecoration(
                    hintText: 'Select aircraft type',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  dropdownColor: AppColors.surfaceVariant,
                  items: AppConstants.aircraftTypes.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value,
                                style: TextStyle(
                                    color: AppColors.onSurface)),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _aircraftType = v ?? ''),
                ),
                const SizedBox(height: 20),

                // Aircraft registration
                const _SectionLabel(label: 'Aircraft Registration'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _regController,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'e.g. G-BXYZ',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),

                // Departure + Arrival
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(label: 'Departure (ICAO)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _departureController,
                            textCapitalization:
                                TextCapitalization.characters,
                            style:
                                TextStyle(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'EGBJ',
                              hintStyle: TextStyle(
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionLabel(label: 'Arrival (ICAO)'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _arrivalController,
                            textCapitalization:
                                TextCapitalization.characters,
                            style:
                                TextStyle(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              hintText: 'EGBJ',
                              hintStyle: TextStyle(
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Flight time
                const _SectionLabel(label: 'Flight Time'),
                const SizedBox(height: 8),
                _TimePickerRow(
                  hours: _flightHours,
                  minutes: _flightMinutes,
                  maxHours: 8,
                  onChanged: (h, m) =>
                      setState(() {
                        _flightHours = h;
                        _flightMinutes = m;
                      }),
                ),
                const SizedBox(height: 20),

                // Dual time
                const _SectionLabel(label: 'Dual Time'),
                const SizedBox(height: 8),
                _TimePickerRow(
                  hours: _dualHours,
                  minutes: _dualMinutes,
                  onChanged: (h, m) =>
                      setState(() {
                        _dualHours = h;
                        _dualMinutes = m;
                      }),
                ),
                const SizedBox(height: 20),

                // PIC time
                const _SectionLabel(label: 'PIC Time'),
                const SizedBox(height: 8),
                _TimePickerRow(
                  hours: _picHours,
                  minutes: _picMinutes,
                  onChanged: (h, m) =>
                      setState(() {
                        _picHours = h;
                        _picMinutes = m;
                      }),
                ),
                const SizedBox(height: 20),

                // Landings
                const _SectionLabel(label: 'Landings'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _landingsController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      final n = int.tryParse(value);
                      if (n == null || n < 0) return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Exercise covered
                const _SectionLabel(label: 'Exercise Covered'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedExercise,
                  decoration: InputDecoration(
                    hintText: 'Select exercise',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                  dropdownColor: AppColors.surfaceVariant,
                  isExpanded: true,
                  items: [
                    ...AppConstants.exerciseNames.entries.map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value,
                          style: TextStyle(
                              color: AppColors.onSurface, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'custom',
                      child: Text(
                        'Custom / Other',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _selectedExercise = v ?? 'ex_01'),
                ),

                // Custom exercise name
                if (_selectedExercise == 'custom') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _customExerciseController,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: AppColors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Enter exercise name',
                      hintStyle:
                          TextStyle(color: AppColors.onSurfaceVariant),
                      prefixIcon: Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    validator: (value) {
                      if (_selectedExercise == 'custom' &&
                          (value == null || value.trim().isEmpty)) {
                        return 'Please enter an exercise name';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Instructor name
                const _SectionLabel(label: 'Instructor Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _instructorController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'e.g. John Smith',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 20),

                // Remarks
                const _SectionLabel(label: 'Remarks'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _remarksController,
                  maxLines: 3,
                  maxLength: InputSanitiser.maxMedium,
                  style: TextStyle(color: AppColors.onSurface),
                  decoration: InputDecoration(
                    hintText: 'Optional notes...',
                    hintStyle:
                        TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 32),

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
                      : const Text(
                          'Save Entry',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section label
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time picker row (hours + minutes dropdowns)
// ---------------------------------------------------------------------------

class _TimePickerRow extends StatelessWidget {
  final int hours;
  final int minutes;
  final int maxHours;
  final void Function(int hours, int minutes) onChanged;

  const _TimePickerRow({
    required this.hours,
    required this.minutes,
    required this.onChanged,
    this.maxHours = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Hours
        Flexible(
          child: DropdownButtonFormField<int>(
            initialValue: hours,
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            dropdownColor: AppColors.surfaceVariant,
            items: List.generate(
              maxHours + 1,
              (i) => DropdownMenuItem(
                value: i,
                child: Text('$i h',
                    style: TextStyle(color: AppColors.onSurface)),
              ),
            ),
            onChanged: (v) => onChanged(v ?? 0, minutes),
          ),
        ),
        const SizedBox(width: 10),
        // Minutes
        Flexible(
          child: DropdownButtonFormField<int>(
            initialValue: minutes,
            decoration: InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            dropdownColor: AppColors.surfaceVariant,
            items: List.generate(
              60,
              (i) => DropdownMenuItem(
                value: i,
                child: Text('${i.toString().padLeft(2, '0')} m',
                    style: TextStyle(color: AppColors.onSurface)),
              ),
            ),
            onChanged: (v) => onChanged(hours, v ?? 0),
          ),
        ),
      ],
    );
  }
}

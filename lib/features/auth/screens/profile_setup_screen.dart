// Profile setup screen — aircraft type, flight school, home airfield, and
// onboarding assessment quiz.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/auth/services/auth_service.dart';

// ── Exercise name lookup ──────────────────────────────────────────────────────
const Map<int, String> _exerciseNames = {
  1: 'Familiarisation',
  2: 'Preparation & Lookout',
  3: 'Air Experience',
  4: 'Effects of Controls',
  5: 'Taxiing',
  6: 'Straight & Level',
  7: 'Climbing',
  8: 'Descending',
  9: 'Turning',
  10: 'Slow Flight',
  11: 'Stalling',
  12: 'Spinning Awareness',
  13: 'Forced Landings',
  14: 'Precautionary Landings',
  15: 'First Solo',
  16: 'Solo Consolidation',
  17: 'Advanced Turning',
  18: 'Navigation',
  19: 'Instrument Appreciation',
};

// ── Quiz data model ───────────────────────────────────────────────────────────

class _QuizAnswer {
  final String label;
  // Positive number = set suggestion to this exercise; negative = skip to next
  // question; -1 used as sentinel for "continue"
  final int? suggestExercise; // null means continue to next question
  final int? adjustBy;        // relative adjustment applied at result step

  const _QuizAnswer({
    required this.label,
    this.suggestExercise,
    this.adjustBy,
  });
}

class _QuizQuestion {
  final String text;
  final List<_QuizAnswer> answers;

  const _QuizQuestion({required this.text, required this.answers});
}

const List<_QuizQuestion> _questions = [
  _QuizQuestion(
    text: 'Have you flown in a light aircraft before?',
    answers: [
      _QuizAnswer(label: 'Never been in one', suggestExercise: 1),
      _QuizAnswer(label: "I've been a passenger", suggestExercise: 1),
      _QuizAnswer(label: "I've had a trial lesson or two", suggestExercise: 3),
      _QuizAnswer(label: "I've started formal lessons"),
    ],
  ),
  _QuizQuestion(
    text: 'Can you maintain straight and level flight without much input from your instructor?',
    answers: [
      _QuizAnswer(label: 'Not yet', suggestExercise: 3),
      _QuizAnswer(label: 'Getting there', suggestExercise: 4),
      _QuizAnswer(label: 'Yes, comfortably'),
    ],
  ),
  _QuizQuestion(
    text: 'Have you practised climbing and descending?',
    answers: [
      _QuizAnswer(label: 'No', suggestExercise: 5),
      _QuizAnswer(label: 'A little', suggestExercise: 5),
      _QuizAnswer(label: 'Yes'),
    ],
  ),
  _QuizQuestion(
    text: 'Can you fly a basic circuit (takeoff, crosswind, downwind, base, final)?',
    answers: [
      _QuizAnswer(label: 'No', suggestExercise: 6),
      _QuizAnswer(label: 'With lots of help', suggestExercise: 7),
      _QuizAnswer(label: 'Mostly yes'),
    ],
  ),
  _QuizQuestion(
    text: 'Have you gone solo?',
    answers: [
      _QuizAnswer(label: 'No', suggestExercise: 10),
      _QuizAnswer(label: 'Yes'),
    ],
  ),
  _QuizQuestion(
    text: 'Have you done any solo navigation flying?',
    answers: [
      _QuizAnswer(label: 'No', suggestExercise: 14),
      _QuizAnswer(label: 'A little', suggestExercise: 15),
      _QuizAnswer(label: 'Yes'),
    ],
  ),
  _QuizQuestion(
    text: "Are you preparing for your skills test?",
    answers: [
      _QuizAnswer(label: 'Not yet', suggestExercise: 17),
      _QuizAnswer(label: 'Actively preparing', suggestExercise: 18),
      _QuizAnswer(label: 'Already done!', suggestExercise: 19),
    ],
  ),
  _QuizQuestion(
    text: 'What would you most like to improve right now?',
    answers: [
      _QuizAnswer(label: 'Basic handling', adjustBy: -2),
      _QuizAnswer(label: 'Navigation', suggestExercise: 14),
      _QuizAnswer(label: 'Emergency procedures', suggestExercise: 18),
      _QuizAnswer(label: 'Exam prep', suggestExercise: 19),
    ],
  ),
];

// ── Screen steps ──────────────────────────────────────────────────────────────

enum _Step { profileForm, quiz, result }

/// Collects aircraft type, flight school, home airfield, and runs the
/// onboarding assessment quiz to suggest a starting exercise.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _icaoController = TextEditingController();
  String? _selectedAircraft;
  int _currentExerciseNumber = 1;
  bool _loading = false;

  // Quiz state
  _Step _step = _Step.profileForm;
  int _quizQuestionIndex = 0;
  int? _pendingSuggestion; // built up as the decision tree progresses
  int? _finalSuggestion;  // set when quiz completes

  // Whether the user has already completed the quiz (skip flag)
  bool _quizAlreadyDone = false;

  @override
  void initState() {
    super.initState();
    _displayNameController.text =
        FirebaseAuth.instance.currentUser?.displayName ?? '';
    _checkExistingQuizResult();
  }

  /// If the Firestore doc already has suggested_exercise_number set, skip the
  /// quiz and go straight to completing profile.
  Future<void> _checkExistingQuizResult() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['suggested_exercise_number'] != null) {
          if (mounted) setState(() => _quizAlreadyDone = true);
        }
      }
    } catch (_) {
      // Non-fatal — proceed with quiz if check fails
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _schoolController.dispose();
    _icaoController.dispose();
    super.dispose();
  }

  // ── Quiz logic ──────────────────────────────────────────────────────────────

  void _onAnswerTapped(_QuizAnswer answer) {
    final isLastQuestion = _quizQuestionIndex == _questions.length - 1;

    if (answer.suggestExercise != null) {
      // Hard suggestion: set and show result
      int suggestion = answer.suggestExercise!;
      if (answer.adjustBy != null) {
        suggestion = (suggestion + answer.adjustBy!).clamp(1, 19);
      }
      // Apply any accumulated relative adjustment
      setState(() {
        _finalSuggestion = suggestion.clamp(1, 19);
        _step = _Step.result;
      });
    } else if (answer.adjustBy != null) {
      // Relative adjustment on the current pending suggestion
      final base = _pendingSuggestion ?? _currentExerciseNumber;
      setState(() {
        _finalSuggestion = (base + answer.adjustBy!).clamp(1, 19);
        _step = _Step.result;
      });
    } else if (isLastQuestion) {
      // Last question, no explicit suggestion — use pending or current
      setState(() {
        _finalSuggestion = (_pendingSuggestion ?? _currentExerciseNumber).clamp(1, 19);
        _step = _Step.result;
      });
    } else {
      // Continue to next question
      setState(() => _quizQuestionIndex++);
    }
  }

  // ── Firestore save ──────────────────────────────────────────────────────────

  /// Saves the profile and (optionally) the suggested exercise number.
  Future<void> _complete({int? suggestedExercise, bool useManual = false}) async {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;

      // If user chose "Start here" use the suggested exercise; otherwise keep
      // whatever they picked in the dropdown.
      final exerciseToSave = (!useManual && suggestedExercise != null)
          ? suggestedExercise
          : _currentExerciseNumber;

      final data = <String, dynamic>{
        'display_name': InputSanitiser.sanitise(
          _displayNameController.text,
          maxLength: InputSanitiser.maxShort,
        ),
        'email': firebaseUser?.email ?? '',
        'aircraft_type': _selectedAircraft,
        'flight_school': InputSanitiser.sanitise(
          _schoolController.text,
          maxLength: InputSanitiser.maxShort,
        ),
        'airfield_icao': InputSanitiser.sanitise(
          _icaoController.text,
          maxLength: 4,
        ).toUpperCase(),
        'current_exercise_number': exerciseToSave,
        if (suggestedExercise != null)
          'suggested_exercise_number': suggestedExercise,
        'has_purchased': false,
        'granted_access': false,
        'subscription_status': 'free',
        'hours_flown': 0,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(data, SetOptions(merge: true));

      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        InputSanitiser.sanitise(
          _displayNameController.text,
          maxLength: InputSanitiser.maxShort,
        ),
      );
      FirebaseAnalytics.instance.logEvent(name: 'profile_completed');

      // Clear the walkthrough flag so new users always see the app tour,
      // even on devices that previously had the app installed.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_seen_walkthrough');

      // Router automatically navigates to /disclaimer
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Profile form validation + proceed ──────────────────────────────────────

  void _submitProfileForm() {
    if (_selectedAircraft == null) {
      setState(() {}); // Trigger rebuild to show aircraft error
      return;
    }
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) return;

    if (_quizAlreadyDone) {
      // Quiz already done on a previous session — save straight away
      _complete();
    } else {
      setState(() {
        _step = _Step.quiz;
        _quizQuestionIndex = 0;
        _pendingSuggestion = null;
        _finalSuggestion = null;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: switch (_step) {
            _Step.profileForm => _buildProfileForm(),
            _Step.quiz       => _buildQuiz(),
            _Step.result     => _buildResult(),
          },
        ),
      ),
    );
  }

  // ── Step 1: profile form ────────────────────────────────────────────────────

  Widget _buildProfileForm() {
    return SingleChildScrollView(
      key: const ValueKey('profile_form'),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sign out escape hatch
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async => AuthService().signOut(),
                child: Text(
                  'Sign out',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.flight_takeoff,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Set up your profile',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Tell us about your training so we can personalise your experience.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _displayNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: InputSanitiser.maxShort,
              decoration: const InputDecoration(
                labelText: 'Display name',
                hintText: 'e.g. John Smith',
                counterText: '',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 28),
            Text(
              'Aircraft type',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            ...AppConstants.aircraftTypes.entries.map(
              (entry) => _AircraftOption(
                value: entry.key,
                label: entry.value,
                selected: _selectedAircraft == entry.key,
                onTap: () => setState(() => _selectedAircraft = entry.key),
              ),
            ),
            if (_selectedAircraft == null && _formKey.currentState != null)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 12),
                child: Text(
                  'Please select an aircraft type',
                  style: TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _schoolController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: InputSanitiser.maxShort,
              decoration: const InputDecoration(
                labelText: 'Flight school',
                hintText: 'e.g. Bournemouth Flying Club',
                counterText: '',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty
                      ? 'Enter your flight school'
                      : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _icaoController,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submitProfileForm(),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'Home airfield (ICAO code)',
                hintText: 'e.g. EGTH',
                helperText: '4-letter ICAO code — optional',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (v.trim().length != 4) return 'ICAO codes are 4 letters';
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _icaoController.clear()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                child: const Text('Skip for now'),
              ),
            ),
            // ── Where are you in your training? ──────────────────────────────
            const SizedBox(height: 28),
            Text(
              'Where are you in your training?',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This determines which exercises you can access for free.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _currentExerciseNumber,
              decoration: const InputDecoration(labelText: 'Current exercise'),
              items: List.generate(19, (i) {
                final exNum = i + 1;
                final paddedNum = exNum.toString().padLeft(2, '0');
                final key = 'ex_$paddedNum';
                final title = AppConstants.exerciseTitles[key]
                    ?? AppConstants.exerciseTitles['ex_${paddedNum}_${paddedNum}a']
                    ?? '';
                return DropdownMenuItem<int>(
                  value: exNum,
                  child: Text(
                    'Ex $exNum \u2013 $title',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }),
              onChanged: (v) {
                if (v != null) setState(() => _currentExerciseNumber = v);
              },
              isExpanded: true,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _loading ? null : _submitProfileForm,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Step 2: quiz ────────────────────────────────────────────────────────────

  Widget _buildQuiz() {
    final question = _questions[_quizQuestionIndex];
    final total = _questions.length;
    final progress = (_quizQuestionIndex + 1) / total;

    return SingleChildScrollView(
      key: ValueKey('quiz_$_quizQuestionIndex'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                if (_quizQuestionIndex > 0) {
                  setState(() => _quizQuestionIndex--);
                } else {
                  setState(() => _step = _Step.profileForm);
                }
              },
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Back'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.onSurfaceVariant,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.divider,
              color: AppColors.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Question ${_quizQuestionIndex + 1} of $total',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            question.text,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 20),
          ...question.answers.map(
            (answer) => _QuizAnswerTile(
              label: answer.label,
              onTap: () => _onAnswerTapped(answer),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Step 3: result ──────────────────────────────────────────────────────────

  Widget _buildResult() {
    final suggestion = _finalSuggestion ?? _currentExerciseNumber;
    final exerciseName = _exerciseNames[suggestion] ?? '';

    return SingleChildScrollView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Based on your answers, we suggest starting at:',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise $suggestion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  exerciseName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading
                ? null
                : () => _complete(suggestedExercise: suggestion, useManual: false),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text('Start at Exercise $suggestion'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loading
                ? null
                : () => _complete(suggestedExercise: suggestion, useManual: true),
            child: Text('Start at Exercise $_currentExerciseNumber (my choice)'),
          ),
          const SizedBox(height: 16),
          Text(
            'You can always change your starting exercise in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _AircraftOption extends StatelessWidget {
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AircraftOption({
    required this.value,
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
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppColors.onSurface : AppColors.onSurfaceVariant,
                fontSize: 15,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizAnswerTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuizAnswerTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.onSurfaceVariant,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

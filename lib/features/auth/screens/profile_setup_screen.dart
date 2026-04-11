// Profile setup screen — aircraft type, flight school, and home airfield selection.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/auth/services/auth_service.dart';

/// Collects aircraft type, flight school, and ICAO code during onboarding.
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
  final _qualificationController = TextEditingController();
  String? _selectedAircraft;
  int _currentExerciseNumber = 1;
  bool _loading = false;
  bool _isInstructor = false;

  @override
  void initState() {
    super.initState();
    // If the user arrived here via the instructor login flow, pre-toggle the
    // instructor switch and clear the flag so it doesn't persist.
    final pendingInstructor = ref.read(pendingInstructorSignupProvider);
    if (pendingInstructor) {
      _isInstructor = true;
      ref.read(pendingInstructorSignupProvider.notifier).state = false;
    }
    _displayNameController.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _schoolController.dispose();
    _icaoController.dispose();
    _qualificationController.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      // Use set+merge so this works whether the doc exists or was deleted
      final firebaseUser = FirebaseAuth.instance.currentUser;
      final data = <String, dynamic>{
        'display_name': InputSanitiser.sanitise(_displayNameController.text, maxLength: InputSanitiser.maxShort),
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
        'user_role': _isInstructor ? 'instructor' : 'student',
        'current_exercise_number': _currentExerciseNumber,
        'has_purchased': false,
        'granted_access': false,
        'subscription_status': 'free',
        'hours_flown': 0,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      // Add instructor-specific fields
      if (_isInstructor) {
        final qualification = InputSanitiser.sanitise(
          _qualificationController.text,
          maxLength: InputSanitiser.maxShort,
        );
        if (qualification.isNotEmpty) {
          data['instructor_qualification'] = qualification;
        }
        // Generate a cryptographically random 6-char alphanumeric invite code
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        final rng = Random.secure();
        data['invite_code'] = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        data,
        SetOptions(merge: true),
      );

      // Write invite code to a dedicated lookup collection so students can
      // find an instructor without reading the full users collection.
      if (_isInstructor && data['invite_code'] != null) {
        await FirebaseFirestore.instance
            .collection('invite_codes')
            .doc(data['invite_code'] as String)
            .set({'instructor_id': uid});
      }
      await FirebaseAuth.instance.currentUser?.updateDisplayName(
        InputSanitiser.sanitise(_displayNameController.text, maxLength: InputSanitiser.maxShort),
      );
      FirebaseAnalytics.instance.logEvent(name: 'profile_completed');

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sign out escape hatch — always visible
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      await AuthService().signOut();
                    },
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
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 28),
                // ── Instructor toggle ───────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'I am a flight instructor',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Enable the instructor dashboard to manage students.',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    value: _isInstructor,
                    onChanged: (v) => setState(() => _isInstructor = v),
                    activeThumbColor: AppColors.primary,
                  ),
                ),
                if (_isInstructor) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _qualificationController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    maxLength: InputSanitiser.maxShort,
                    decoration: const InputDecoration(
                      labelText: 'Instructor qualification / number (optional)',
                      hintText: 'e.g. FI(A) 12345',
                      counterText: '',
                    ),
                  ),
                ],
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
                      v == null || v.trim().isEmpty ? 'Enter your flight school' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _icaoController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _complete(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Home airfield (ICAO code)',
                    hintText: 'e.g. EGHH',
                    helperText: '4-letter ICAO code',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your airfield ICAO code';
                    if (v.trim().length != 4) return 'ICAO codes are 4 letters';
                    return null;
                  },
                ),
                // ── Where are you in training? ─────────────────
                if (!_isInstructor) ...[
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
                    decoration: const InputDecoration(
                      labelText: 'Current exercise',
                    ),
                    items: List.generate(19, (i) {
                      final exNum = i + 1;
                      final paddedNum = exNum.toString().padLeft(2, '0');
                      final key = 'ex_$paddedNum';
                      // Exercises 10 and 18 only have sub-exercise entries
                      final title = AppConstants.exerciseTitles[key]
                          ?? AppConstants.exerciseTitles['ex_${paddedNum}_${paddedNum}a']
                          ?? '';
                      return DropdownMenuItem<int>(
                        value: exNum,
                        child: Text(
                          'Ex $exNum – $title',
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
                ],
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          if (_selectedAircraft == null) {
                            setState(() {}); // Trigger rebuild to show aircraft error
                            return; // Don't proceed without aircraft selection
                          }
                          _complete();
                        },
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Get Started'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
          color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
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

// Profile edit screen — allows updating display name, aircraft type, flight
// school, and home airfield ICAO code.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

// ---------------------------------------------------------------------------
// Aircraft dropdown options
// ---------------------------------------------------------------------------
const _aircraftOptions = [
  (value: 'cessna_152', label: 'Cessna 152'),
  (value: 'cessna_172', label: 'Cessna 172'),
  (value: 'pa28', label: 'Piper PA-28 Warrior'),
  (value: 'pa28_181', label: 'Piper PA-28-181 Archer'),
  (value: 'pa38', label: 'Piper PA-38 Tomahawk'),
  (value: 'da40', label: 'Diamond DA40'),
  (value: 'da20', label: 'Diamond DA20 Katana'),
  (value: 'robin_dr400', label: 'Robin DR400'),
  (value: 'grob_g115', label: 'Grob G115 Tutor'),
  (value: 'tecnam_p2002', label: 'Tecnam P2002 Sierra'),
];

// ---------------------------------------------------------------------------
// ProfileEditScreen
// ---------------------------------------------------------------------------
/// Form for editing the user's profile fields.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _flightSchoolController;
  late final TextEditingController _airfieldIcaoController;
  String? _selectedAircraft;

  bool _initialised = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _flightSchoolController = TextEditingController();
    _airfieldIcaoController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _flightSchoolController.dispose();
    _airfieldIcaoController.dispose();
    super.dispose();
  }

  void _initFromUser(dynamic user) {
    if (_initialised || user == null) return;
    _initialised = true;
    _displayNameController.text = user.displayName ?? '';
    _flightSchoolController.text = user.flightSchool ?? '';
    _airfieldIcaoController.text =
        (user.airfieldIcao as String? ?? '').toUpperCase();
    final knownValues = _aircraftOptions.map((o) => o.value).toList();
    _selectedAircraft = knownValues.contains(user.aircraftType)
        ? user.aircraftType as String
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    setState(() => _saving = true);

    try {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.updateUser(uid, {
        'display_name': InputSanitiser.sanitise(
          _displayNameController.text,
          maxLength: InputSanitiser.maxName,
        ),
        'flight_school': InputSanitiser.sanitise(
          _flightSchoolController.text,
          maxLength: InputSanitiser.maxShort,
        ),
        'airfield_icao': InputSanitiser.sanitise(
          _airfieldIcaoController.text.toUpperCase(),
          maxLength: 4,
        ),
        if (_selectedAircraft != null) 'aircraft_type': _selectedAircraft,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving profile. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Text(
            'Unable to load profile. Please try again.',
            style: TextStyle(color: AppColors.error),
          ),
        ),
        data: (user) {
          _initFromUser(user);

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                // ── Display Name ────────────────────────────────────────
                const _FieldLabel('Display Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _displayNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Display name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Aircraft Type ───────────────────────────────────────
                const _FieldLabel('Aircraft Type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedAircraft,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.flight_rounded),
                  ),
                  hint: const Text('Select aircraft'),
                  items: _aircraftOptions.map((opt) {
                    return DropdownMenuItem<String>(
                      value: opt.value,
                      child: Text(opt.label),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAircraft = v),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please select an aircraft type';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ── Flight School ───────────────────────────────────────
                const _FieldLabel('Flight School'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _flightSchoolController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Flight school',
                    hintText: 'e.g. Bournemouth Flying Club',
                    prefixIcon: Icon(Icons.school_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Enter your flight school'
                      : null,
                ),
                const SizedBox(height: 20),

                // ── Home Airfield ICAO ──────────────────────────────────
                const _FieldLabel('Home Airfield (ICAO)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _airfieldIcaoController,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    _UpperCaseTextFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Home airfield (ICAO code)',
                    prefixIcon: Icon(Icons.flight_land_rounded),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Enter your airfield ICAO code';
                    }
                    if (v.trim().length != 4) {
                      return 'ICAO codes are exactly 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 36),

                // ── Save button ─────────────────────────────────────────
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

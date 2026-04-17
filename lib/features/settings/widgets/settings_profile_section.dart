import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/shared/models/app_user.dart';

// ---------------------------------------------------------------------------
// Aircraft type label helper
// ---------------------------------------------------------------------------
String settingsAircraftLabel(String type) =>
    AppConstants.aircraftTypes[type] ?? (type.isNotEmpty ? type : 'Not set');

// ---------------------------------------------------------------------------
// Profile section
// ---------------------------------------------------------------------------
class SettingsProfileSection extends StatelessWidget {
  final AppUser? user;

  const SettingsProfileSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayName = user?.displayName ?? 'Student Pilot';
    final email = user?.email ?? '';
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'S';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: cs.primary,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/settings/profile'),
            style: TextButton.styleFrom(
              foregroundColor: cs.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aircraft & Training section
// ---------------------------------------------------------------------------
class SettingsAircraftSection extends StatelessWidget {
  final AppUser? user;

  const SettingsAircraftSection({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final aircraft = settingsAircraftLabel(user?.aircraftType ?? '');
    final school = user?.flightSchool.isNotEmpty == true
        ? user!.flightSchool
        : 'Not set';
    final airfield = user?.airfieldIcao.isNotEmpty == true
        ? user!.airfieldIcao.toUpperCase()
        : 'Not set';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          SettingsInfoRow(label: 'Aircraft type', value: aircraft),
          Divider(color: cs.outline, height: 20),
          SettingsInfoRow(label: 'Flight school', value: school),
          Divider(color: cs.outline, height: 20),
          SettingsInfoRow(label: 'Home airfield', value: airfield),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/settings/profile'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: cs.outline),
                foregroundColor: cs.onSurface.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Edit Aircraft & Training'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row
// ---------------------------------------------------------------------------
class SettingsInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const SettingsInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: cs.onSurface.withValues(alpha: 0.6),
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: cs.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Home > Greeting header card.
// Extracted from home_screen.dart during 2026-04-13 refactor.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/app_user.dart';

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class GreetingHeader extends StatelessWidget {
  final AppUser? user;
  const GreetingHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final firstName = _extractFirstName(user?.displayName ?? '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firstName.isNotEmpty
                    ? '${_greeting()}, $firstName'
                    : _greeting(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _subtitleText(user),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/settings/profile'),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ],
    ),
    );
  }

  static String _extractFirstName(String fullName) {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').first;
  }

  static String _subtitleText(AppUser? user) {
    if (user == null) return 'Welcome to Flight Path Training';
    final aircraft =
        AppConstants.aircraftTypes[user.aircraftType] ?? '';
    if (aircraft.isNotEmpty) return 'Flying a $aircraft';
    return 'Welcome to Flight Path Training';
  }
}

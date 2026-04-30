// Tools tab landing screen.
// Shows cards for each pilot tool: Weather, METAR Training, QXC Guide,
// Airfield Info, Aircraft Data. The Weather card shows an offline badge when
// there is no network connection.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/services/connectivity_service.dart';

class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isOnline = ref.watch(isOnlineProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'Tools',
                style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Reference tools for your flying',
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.55),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              _WeatherToolCard(isOnline: isOnline),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.cloud_rounded,
                title: 'METAR Training',
                description: 'Decode live weather reports',
                onTap: () => context.push('/tools/metar'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.map_rounded,
                title: 'QXC Guide',
                description: 'Learn to plan your cross-country',
                onTap: () => context.push('/tools/qxc'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.local_airport_rounded,
                title: 'Airfield Info',
                description: 'Circuits, frequencies and local rules',
                onTap: () => context.push('/tools/airfield'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.speed_rounded,
                title: 'Aircraft Data',
                description: 'Performance figures for your aircraft',
                onTap: () => context.push('/tools/aircraft'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.warning_amber_rounded,
                title: 'Emergency Drills',
                description: 'Engine failures, fires and emergency actions',
                onTap: () => context.push('/tools/emergency-drills'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.menu_book_rounded,
                title: 'Memory Drills',
                description: 'Speeds, mnemonics and circuit checks',
                onTap: () => context.push('/tools/memory-drills'),
              ),
              const SizedBox(height: 12),
              _ToolCard(
                icon: Icons.assignment_turned_in_rounded,
                title: 'Mock Skills Test',
                description: 'Self-assess against CAA examiner standards',
                onTap: () => context.push('/tools/mock-skills-test'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeatherToolCard extends StatelessWidget {
  final bool isOnline;

  const _WeatherToolCard({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () {
        if (!isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Weather requires an internet connection.'),
            ),
          );
          return;
        }
        context.push('/tools/weather');
      },
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outline),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.wb_cloudy_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weather Briefing',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Current conditions for your airfield',
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: cs.onSurface.withValues(alpha: 0.3),
                  size: 22,
                ),
              ],
            ),
          ),
          if (!isOnline)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cs.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.outline),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 14,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: 0.3),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

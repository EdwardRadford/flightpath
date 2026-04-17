// Hours screen — breakdown of flight hours by month and cumulative total.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';

/// Displays cumulative and per-month flight hours from completed lessons.
class HoursScreen extends ConsumerWidget {
  const HoursScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(appUserProvider);
    final lessonsAsync = ref.watch(allLessonsProvider);

    return Scaffold(
      
      appBar: AppBar(
        title: const Text(
          'Flight Hours',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Text('Unable to load data. Please try again.',
              style: TextStyle(color: AppColors.error)),
        ),
        data: (user) {
          if (user == null) {
            return  Center(
              child: Text('Not signed in',
                  style: TextStyle(color: AppColors.onSurfaceVariant)),
            );
          }

          if (lessonsAsync.hasError) {
            return const Center(
              child: Text(
                'Unable to load flight hours. Please try again.',
                style: TextStyle(color: AppColors.error),
              ),
            );
          }
          if (lessonsAsync.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final completedLessons = (lessonsAsync.valueOrNull ?? [])
              .where((l) => l.status == LessonStatus.completed)
              .toList();

          // Calculate total hours from lesson durations
          int totalMinutes = 0;
          for (final lesson in completedLessons) {
            totalMinutes += lesson.lessonDuration;
          }
          final totalHours = totalMinutes / 60;

          // Group lessons by month
          final byMonth = <String, List<Lesson>>{};
          for (final lesson in completedLessons) {
            final date = lesson.lessonDate ?? lesson.createdAt;
            final key = DateFormat('MMMM yyyy').format(date);
            byMonth.putIfAbsent(key, () => []).add(lesson);
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // ── Total hours card ──────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: Theme.of(context).brightness == Brightness.dark
                          ? const [AppColors.heroGradientStart, AppColors.heroGradientEnd]
                          : [AppColors.primaryLight, AppColors.surfaceVariantLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha:0.35),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.flight_rounded,
                        color: AppColors.primary,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        totalHours.toStringAsFixed(1),
                        style:  TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 48,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                       Text(
                        'Total Hours',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _MiniStat(
                            label: 'Lessons',
                            value: '${completedLessons.length}',
                          ),
                          const SizedBox(width: 32),
                          _MiniStat(
                            label: 'Avg Duration',
                            value: completedLessons.isEmpty
                                ? '—'
                                : '${(totalMinutes / completedLessons.length).round()} min',
                          ),
                          const SizedBox(width: 32),
                          _MiniStat(
                            label: 'Avg Rating',
                            value: _averageRating(completedLessons),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Hours target progress ─────────────────────────────
                _HoursTargetCard(currentHours: totalHours),

                const SizedBox(height: 28),

                // ── Monthly breakdown ─────────────────────────────────
                if (byMonth.isNotEmpty) ...[
                   Text(
                    'Monthly Breakdown',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...byMonth.entries.map((entry) {
                    int monthMinutes = 0;
                    for (final l in entry.value) {
                      monthMinutes += l.lessonDuration;
                    }
                    return _MonthRow(
                      month: entry.key,
                      lessons: entry.value.length,
                      hours: monthMinutes / 60,
                    );
                  }),
                ],

                if (byMonth.isEmpty)
                  const EmptyStateWidget(
                    icon: Icons.flight_rounded,
                    title: 'No hours logged yet',
                    subtitle: 'Complete your first lesson to see your hours here.',
                  ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String _averageRating(List<Lesson> lessons) {
    final rated = lessons.where((l) => l.studentRating != null).toList();
    if (rated.isEmpty) return '—';
    final avg =
        rated.map((l) => l.studentRating!).reduce((a, b) => a + b) /
            rated.length;
    return avg.toStringAsFixed(1);
  }
}

// ---------------------------------------------------------------------------
// Hours target card — PPL(A) requires minimum 45 hours
// ---------------------------------------------------------------------------

class _HoursTargetCard extends StatelessWidget {
  final double currentHours;
  static const double _pplMinimum = 45.0;

  const _HoursTargetCard({required this.currentHours});

  @override
  Widget build(BuildContext context) {
    final progress = (currentHours / _pplMinimum).clamp(0.0, 1.0);
    final remaining = (_pplMinimum - currentHours).clamp(0.0, _pplMinimum);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Text(
                'PPL(A) Minimum Hours',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${currentHours.toStringAsFixed(1)} / ${_pplMinimum.toInt()} hrs',
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceVariant,
              valueColor:
                  AlwaysStoppedAnimation<Color>(
                progress >= 1.0 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            progress >= 1.0
                ? 'Minimum hours reached!'
                : '${remaining.toStringAsFixed(1)} hours remaining',
            style: TextStyle(
              color: progress >= 1.0
                  ? AppColors.success
                  : AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini stat
// ---------------------------------------------------------------------------

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style:  TextStyle(
            color: AppColors.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style:  TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month row
// ---------------------------------------------------------------------------

class _MonthRow extends StatelessWidget {
  final String month;
  final int lessons;
  final double hours;

  const _MonthRow({
    required this.month,
    required this.lessons,
    required this.hours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              month,
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '$lessons lesson${lessons == 1 ? '' : 's'}',
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${hours.toStringAsFixed(1)} hrs',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

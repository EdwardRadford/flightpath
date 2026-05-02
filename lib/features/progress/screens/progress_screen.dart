// Progress screen — tabbed view of syllabus progress by exercise, by lesson
// history, and overall completion stats.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/exercises/providers/syllabus_progress_provider.dart';
import 'package:flight_path/features/exercises/widgets/exercise_list/flight_path_body.dart'
    show kExercises;
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/features/progress/screens/hours_minimums_screen.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// Syllabus phases
const _phases = [
  _Phase(
    name: 'Phase 1 – Basics',
    subtitle: 'Exercises 1–9',
    ids: ['ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05', 'ex_06', 'ex_07', 'ex_08', 'ex_09'],
  ),
  _Phase(
    name: 'Phase 2 – Manoeuvres',
    subtitle: 'Exercises 10–13',
    ids: ['ex_10_10a', 'ex_10_10b', 'ex_11', 'ex_12', 'ex_13'],
  ),
  _Phase(
    name: 'Phase 3 – First Solo',
    subtitle: 'Exercise 14',
    ids: ['ex_14'],
  ),
  _Phase(
    name: 'Phase 4 – Advanced',
    subtitle: 'Exercises 15–19',
    ids: ['ex_15', 'ex_16', 'ex_17', 'ex_18_18a', 'ex_18_18b', 'ex_18_18c', 'ex_19'],
  ),
];

class _Phase {
  final String name;
  final String subtitle;
  final List<String> ids;
  const _Phase({required this.name, required this.subtitle, required this.ids});
}

// ---------------------------------------------------------------------------
// ProgressScreen
// ---------------------------------------------------------------------------
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  static const _tabNames = ['lessons', 'hours', 'syllabus', 'minimums'];
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    FirebaseAnalytics.instance.logEvent(
      name: 'progress_viewed',
      parameters: {'tab_name': 'lessons'},
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        FirebaseAnalytics.instance.logEvent(
          name: 'progress_viewed',
          parameters: {'tab_name': _tabNames[_tabController.index]},
        );
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        
        appBar: AppBar(
          title: const Text('Progress'),
          
          elevation: 0,
          actions: [
            IconButton(
              onPressed: () => context.push('/achievements'),
              icon: const Icon(Icons.military_tech_rounded),
              tooltip: 'Achievements',
            ),
            IconButton(
              onPressed: () => context.push('/goals'),
              icon: const Icon(Icons.emoji_events_rounded),
              tooltip: 'My Goals',
            ),
            IconButton(
              onPressed: () => context.push('/share-progress'),
              icon: const Icon(Icons.share_rounded),
              tooltip: 'Share with Instructor',
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: AppColors.primary,
            labelColor: AppColors.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            tabs: const [
              Tab(text: 'Lessons'),
              Tab(text: 'Hours'),
              Tab(text: 'Syllabus'),
              Tab(text: 'Minimums'),
            ],
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(
                'Your training analytics and CAA progress',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _LessonsTab(),
                  _HoursTab(),
                  _SyllabusTab(),
                  HoursMinimumsScreen(),
                ],
              ),
            ),
          ],
        ),
      );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Lessons
// ---------------------------------------------------------------------------
class _LessonsTab extends ConsumerWidget {
  const _LessonsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return lessonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load progress'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(allLessonsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (lessons) {
        if (lessons.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.trending_up_rounded,
            title: 'Nothing to track yet',
            subtitle:
                'Complete exercises and log lessons to see your progress here.',
            buttonText: 'Go to Exercises',
            onButtonPressed: () => context.push('/exercises'),
          );
        }

        final completed =
            lessons.where((l) => l.status == LessonStatus.completed).length;

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: lessons.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completed completed',
                              style:  TextStyle(
                                color: AppColors.onSurface,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                             Text(
                              'All your lessons',
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.flight_takeoff_rounded,
                          color: AppColors.primary, size: 28),
                    ],
                  ),
                ),
              );
            }

            return _LessonTile(lesson: lessons[index - 1]);
          },
        );
      },
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;

  const _LessonTile({required this.lesson});

  Color _ratingColor(int? rating) {
    if (rating == null) return AppColors.onSurfaceVariant;
    if (rating <= 2) return AppColors.error;
    if (rating <= 4) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.scheduledDate ?? lesson.createdAt;

    final primaryKey = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;
    final primaryName = exerciseLongName(primaryKey);

    final ratingColor = _ratingColor(lesson.studentRating);

    String statusLabel;
    switch (lesson.status) {
      case LessonStatus.completed:
        statusLabel = 'Completed';
        break;
      case LessonStatus.scheduled:
        statusLabel = 'Scheduled';
        break;
      case LessonStatus.prepared:
        statusLabel = 'Prepared';
        break;
      case LessonStatus.cancelled:
        statusLabel = 'Cancelled';
        break;
      case LessonStatus.manualEntry:
        statusLabel = 'Manual Entry';
        break;
    }

    return GestureDetector(
      onTap: () => context.push('/lesson-detail', extra: lesson),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ratingColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: ratingColor),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                primaryName,
                                style:  TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (lesson.additionalExerciseIds.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: lesson.additionalExerciseIds
                                      .map((id) {
                                    final name = exerciseLongName(id);
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        name,
                                        style:  TextStyle(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('d MMM yyyy').format(date),
                                    style:  TextStyle(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ratingColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      statusLabel,
                                      style: TextStyle(
                                        color: ratingColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (lesson.studentRating != null) ...[
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.star_rounded,
                                      color: ratingColor, size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${lesson.studentRating}/5',
                                    style: TextStyle(
                                      color: ratingColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (lesson.lessonDuration > 0)
                                Text(
                                  _formatDuration(lesson.lessonDuration),
                                  style:  TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Hours / Logbook
// ---------------------------------------------------------------------------
enum _HoursFilter { all, thisMonth, thisYear }

class _HoursTab extends ConsumerStatefulWidget {
  const _HoursTab();

  @override
  ConsumerState<_HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends ConsumerState<_HoursTab> {
  _HoursFilter _filter = _HoursFilter.all;

  static const double _pplGoal = 45.0;

  // Exercise 14 is the First Solo milestone — treated as solo time.
  static const String _firstSoloId = 'ex_14';

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'logbook_viewed');
  }

  List<Lesson> _filtered(List<Lesson> lessons) {
    final now = DateTime.now();
    switch (_filter) {
      case _HoursFilter.all:
        return lessons;
      case _HoursFilter.thisMonth:
        return lessons.where((l) {
          final d = l.lessonDate ?? l.createdAt;
          return d.year == now.year && d.month == now.month;
        }).toList();
      case _HoursFilter.thisYear:
        return lessons.where((l) {
          final d = l.lessonDate ?? l.createdAt;
          return d.year == now.year;
        }).toList();
    }
  }

  double _totalHours(List<Lesson> lessons) {
    double total = 0;
    for (final l in lessons) {
      if (l.lessonDuration > 0 && l.status == LessonStatus.completed) {
        total += l.lessonDuration / 60.0;
      }
    }
    return total;
  }

  bool _isSolo(Lesson l) => l.exerciseId == _firstSoloId;

  /// Format minutes as "1:30" (CAA logbook style hh:mm).
  String _hhMm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return lessonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load progress'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(allLessonsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allLessons) {
        // All completed lessons across all time (for the circular indicator).
        final allCompleted = allLessons
            .where((l) => l.status == LessonStatus.completed)
            .toList();
        final totalHoursFlown = _totalHours(allCompleted);
        final progress = (totalHoursFlown / _pplGoal).clamp(0.0, 1.0);

        // Dual / solo split (all time).
        final soloLessons = allCompleted.where(_isSolo).toList();
        final dualLessons = allCompleted.where((l) => !_isSolo(l)).toList();
        final soloHours = _totalHours(soloLessons);
        final dualHours = _totalHours(dualLessons);

        // Filtered set for the logbook table.
        final filtered = _filtered(allLessons);
        final filteredHours = _totalHours(filtered);
        final completedFiltered = filtered
            .where((l) => l.status == LessonStatus.completed)
            .toList()
          ..sort((a, b) {
            final da = a.lessonDate ?? a.createdAt;
            final db = b.lessonDate ?? b.createdAt;
            return db.compareTo(da); // newest first
          });

        // Totals for the logbook table footer.
        int totalMinutesFiltered = 0;
        for (final l in completedFiltered) {
          totalMinutesFiltered += l.lessonDuration;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Circular progress + hours ──────────────────────────────
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                totalHoursFlown.toStringAsFixed(1),
                                style:  TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                               Text(
                                'hrs flown',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Goal: ${_pplGoal.toStringAsFixed(0)} hrs '
                      '(${(progress * 100).round()}% complete)',
                      style:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(_pplGoal - totalHoursFlown).clamp(0.0, _pplGoal).toStringAsFixed(1)} hrs to go',
                      style:  TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Dual / Solo split ──────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Dual',
                        hours: dualHours,
                        lessons: dualLessons.length,
                        icon: Icons.people_alt_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 52,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Solo',
                        hours: soloHours,
                        lessons: soloLessons.length,
                        icon: Icons.person_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 52,
                      color: AppColors.divider,
                    ),
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Total',
                        hours: totalHoursFlown,
                        lessons: allCompleted.length,
                        icon: Icons.flight_rounded,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── Filter chips ───────────────────────────────────────────
              Row(
                children: [
                  _FilterChip(
                    label: 'All Time',
                    selected: _filter == _HoursFilter.all,
                    onTap: () =>
                        setState(() => _filter = _HoursFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'This Month',
                    selected: _filter == _HoursFilter.thisMonth,
                    onTap: () =>
                        setState(() => _filter = _HoursFilter.thisMonth),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'This Year',
                    selected: _filter == _HoursFilter.thisYear,
                    onTap: () =>
                        setState(() => _filter = _HoursFilter.thisYear),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Logbook table header ───────────────────────────────────
              Row(
                children:  [
                  Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Flight Logbook',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'CAA PPL(A) format · ${completedFiltered.length} '
                'entr${completedFiltered.length == 1 ? 'y' : 'ies'}',
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),

              if (completedFiltered.isEmpty)
                // Empty state
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child:  Column(
                    children: [
                      Icon(
                        Icons.flight_takeoff_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 40,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No entries for this period',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Complete a lesson and it will appear\nin your logbook.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                // Logbook card
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      // Column headers
                      _LogbookHeaderRow(),

                      Divider(height: 1, color: AppColors.divider),

                      // Data rows
                      ...completedFiltered.asMap().entries.map((entry) {
                        final index = entry.key;
                        final lesson = entry.value;
                        final isLast =
                            index == completedFiltered.length - 1;
                        return _LogbookDataRow(
                          lesson: lesson,
                          isSolo: _isSolo(lesson),
                          hhMm: _hhMm,
                          isLast: isLast,
                        );
                      }),

                      // Totals row
                      Divider(height: 1, color: AppColors.divider),
                      _LogbookTotalsRow(
                        totalLessons: completedFiltered.length,
                        totalMinutes: totalMinutesFiltered,
                        hhMm: _hhMm,
                        filteredHours: filteredHours,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              // CAA disclaimer note
              if (completedFiltered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This digital logbook is for reference only. '
                          'Your official CAA logbook must be maintained separately and '
                          'signed by your instructor.',
                          style:  TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Hours split cell (Dual / Solo / Total)
// ---------------------------------------------------------------------------
class _HoursSplitCell extends StatelessWidget {
  final String label;
  final double hours;
  final int lessons;
  final IconData icon;
  final Color color;

  const _HoursSplitCell({
    required this.label,
    required this.hours,
    required this.lessons,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          hours.toStringAsFixed(1),
          style: TextStyle(
            color: color,
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
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$lessons lesson${lessons == 1 ? '' : 's'}',
          style:  TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook column header row
// ---------------------------------------------------------------------------
class _LogbookHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: Row(
        children: [
          // Date — fixed width
          SizedBox(
            width: 72,
            child: Text(
              'Date',
              style: _headerStyle,
            ),
          ),
          // Exercise — flexible
          Expanded(
            child: Text(
              'Exercise',
              style: _headerStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Duration — fixed
          SizedBox(
            width: 42,
            child: Text(
              'Time',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 6),
          // Type badge — fixed
          SizedBox(
            width: 40,
            child: Text(
              'Type',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 6),
          // Rating — fixed
          SizedBox(
            width: 36,
            child: Text(
              'Rating',
              style: _headerStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static final _headerStyle = TextStyle(
    color: AppColors.onSurfaceVariant,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );
}

// ---------------------------------------------------------------------------
// Logbook data row — one completed lesson
// ---------------------------------------------------------------------------
class _LogbookDataRow extends StatelessWidget {
  final Lesson lesson;
  final bool isSolo;
  final String Function(int) hhMm;
  final bool isLast;

  const _LogbookDataRow({
    required this.lesson,
    required this.isSolo,
    required this.hhMm,
    required this.isLast,
  });

  Color _ratingColor(int? r) {
    if (r == null) return AppColors.onSurfaceVariant;
    if (r <= 2) return AppColors.error;
    if (r <= 4) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('d MMM yy').format(date);

    // Resolve exercise name — handle sub-exercises
    final compositeKey = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;
    final fullName = exerciseLongName(compositeKey);
    // Strip "Exercise N – " prefix for compact display
    final shortName = fullName.contains('–')
        ? fullName.substring(fullName.indexOf('–') + 2)
        : fullName;

    final durationStr =
        lesson.lessonDuration > 0 ? hhMm(lesson.lessonDuration) : '—';

    final ratingColor = _ratingColor(lesson.studentRating);

    return Container(
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(13))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Date
                SizedBox(
                  width: 72,
                  child: Text(
                    dateStr,
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Exercise name
                Expanded(
                  child: Text(
                    shortName,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Duration hh:mm
                SizedBox(
                  width: 42,
                  child: Text(
                    durationStr,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                // Type badge
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSolo
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isSolo ? 'Solo' : 'Dual',
                        style: TextStyle(
                          color: isSolo
                              ? AppColors.success
                              : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Rating
                SizedBox(
                  width: 36,
                  child: lesson.studentRating != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: ratingColor,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${lesson.studentRating}',
                              style: TextStyle(
                                color: ratingColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      :  Text(
                          '—',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ],
            ),
          ),
          if (!isLast)
             Divider(
              height: 1,
              color: AppColors.divider,
              indent: 12,
              endIndent: 12,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook totals row
// ---------------------------------------------------------------------------
class _LogbookTotalsRow extends StatelessWidget {
  final int totalLessons;
  final int totalMinutes;
  final String Function(int) hhMm;
  final double filteredHours;

  const _LogbookTotalsRow({
    required this.totalLessons,
    required this.totalMinutes,
    required this.hhMm,
    required this.filteredHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
      ),
      child: Row(
        children: [
          // Label
           SizedBox(
            width: 72,
            child: Text(
              'TOTALS',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          // Lesson count
          Expanded(
            child: Text(
              '$totalLessons lesson${totalLessons == 1 ? '' : 's'}',
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Total time hh:mm
          SizedBox(
            width: 42,
            child: Text(
              totalMinutes > 0 ? hhMm(totalMinutes) : '—',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Spacer for Type + Rating columns
          const SizedBox(width: 6 + 40 + 6 + 36),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.onSurfaceVariant,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Readiness card
// ---------------------------------------------------------------------------
class _ReadinessCard extends StatelessWidget {
  final SkillsReadinessData data;

  const _ReadinessCard({required this.data});

  Color get _ringColor {
    final pct = data.score * 100;
    if (pct < 40) return AppColors.error;
    if (pct < 70) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final pct = (data.score * 100).round();
    final ringColor = _ringColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: data.score,
                    strokeWidth: 11,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$pct%',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'readiness',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Skills Test Readiness',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${data.ready} of ${data.total} exercises rated 4+ / 5',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ReadinessBreakdownCell(
                  label: 'Ready',
                  count: data.ready,
                  color: AppColors.success,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              Expanded(
                child: _ReadinessBreakdownCell(
                  label: 'In Progress',
                  count: data.inProgress,
                  color: AppColors.warning,
                ),
              ),
              Container(width: 1, height: 36, color: AppColors.divider),
              Expanded(
                child: _ReadinessBreakdownCell(
                  label: 'Not Started',
                  count: data.notStarted,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadinessBreakdownCell extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ReadinessBreakdownCell({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Syllabus
// ---------------------------------------------------------------------------
class _SyllabusTab extends ConsumerWidget {
  const _SyllabusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(userExercisesProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return exercisesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load progress'),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(userExercisesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (userExercises) {
        // Build lookup map
        final ueMap = <String, UserExercise>{};
        for (final ue in userExercises) {
          final key = ue.subExercise != null
              ? '${ue.exerciseId}_${ue.subExercise}'
              : ue.exerciseId;
          ueMap[key] = ue;
        }

        // Overall % complete is now driven by the unified
        // SyllabusProgress provider (parent-level — sub-exercise parents
        // count only when all children are complete). This keeps the
        // syllabus tab, the home suggestion, and the flight-path map in
        // lock-step.
        final progress = ref.watch(syllabusProgressProvider);
        final totalComplete = progress.completedCount;
        final totalExercises = kExercises.length;

        final readinessData = ref.watch(skillsReadinessDataProvider);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (readinessData != null)
              _ReadinessCard(data: readinessData),
            if (readinessData != null)
              const SizedBox(height: 16),

            // Overall summary
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'CAA PPL(A) Syllabus',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalComplete of $totalExercises exercises complete',
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalExercises > 0
                          ? totalComplete / totalExercises
                          : 0.0,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // Phase cards
            ..._phases.map((phase) {
              final phaseTotal = phase.ids.length;
              final phaseComplete = phase.ids
                  .where((id) => ueMap[id]?.status.isCompleted ?? false)
                  .length;
              final phaseProgress =
                  phaseTotal > 0 ? phaseComplete / phaseTotal : 0.0;

              Color phaseColor;
              if (phaseComplete == phaseTotal) {
                phaseColor = AppColors.success;
              } else if (phaseComplete > 0) {
                phaseColor = AppColors.warning;
              } else {
                phaseColor = AppColors.onSurfaceVariant;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phase.name,
                                  style:  TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  phase.subtitle,
                                  style:  TextStyle(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$phaseComplete/$phaseTotal',
                            style: TextStyle(
                              color: phaseColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: phaseProgress,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(phaseColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                     Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 16,
                      endIndent: 16,
                    ),
                    ...phase.ids.map((id) {
                      final ue = ueMap[id];
                      final bestRating = ue?.bestRating;
                      final name = exerciseLongName(id);
                      final routeId = id; // composite id, e.g. 'ex_10_10a'

                      // Rating colour: grey=none, red=1-2, amber=3-4, green=5
                      Color itemColor;
                      if (bestRating == null) {
                        itemColor = AppColors.onSurfaceVariant;
                      } else if (bestRating <= 2) {
                        itemColor = AppColors.error;
                      } else if (bestRating <= 4) {
                        itemColor = AppColors.warning;
                      } else {
                        itemColor = AppColors.success;
                      }

                      final isLast = id == phase.ids.last;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              final hasAccess = appUser?.canAccessExercise(routeId) ?? true;
                              if (!hasAccess) {
                                showPremiumPaywall(
                                  context,
                                  source: 'syllabus_tab',
                                  freeWindowStart: appUser?.freeWindowStart ?? 1,
                                  freeWindowEnd: appUser?.freeWindowEnd ?? 3,
                                );
                                return;
                              }
                              context.push('/exercises/$routeId');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Colour dot
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: itemColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        color: bestRating == null
                                            ? AppColors.onSurfaceVariant
                                            : AppColors.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (bestRating != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ...List.generate(5, (i) => Icon(
                                          (i + 1) <= bestRating
                                              ? Icons.star_rounded
                                              : Icons.star_outline_rounded,
                                          color: itemColor,
                                          size: 13,
                                        )),
                                      ],
                                    )
                                  else
                                     Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.onSurfaceVariant,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                             Divider(
                              height: 1,
                              color: AppColors.divider,
                              indent: 38,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

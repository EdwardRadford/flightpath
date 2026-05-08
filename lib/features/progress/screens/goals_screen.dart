// Goals screen — displays First Solo and Full PPL training goals with
// target dates, countdown, progress bars, and status badges.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/progress/providers/goals_provider.dart';
import 'package:flight_path/shared/models/goal.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

// ---------------------------------------------------------------------------
// Exercise IDs for each goal milestone
// ---------------------------------------------------------------------------

/// Exercises 1-14 (including sub-exercises) for First Solo.
const _firstSoloIds = [
  'ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05',
  'ex_06', 'ex_07', 'ex_08', 'ex_09',
  'ex_10_10a', 'ex_10_10b',
  'ex_11', 'ex_12', 'ex_13', 'ex_14',
];

/// All 22 exercise/sub-exercise IDs for Full PPL.
const _fullPplIds = [
  'ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05',
  'ex_06', 'ex_07', 'ex_08', 'ex_09',
  'ex_10_10a', 'ex_10_10b',
  'ex_11', 'ex_12', 'ex_13', 'ex_14', 'ex_15',
  'ex_16', 'ex_17',
  'ex_18_18a', 'ex_18_18b', 'ex_18_18c',
  'ex_19',
];

// ---------------------------------------------------------------------------
// GoalsScreen
// ---------------------------------------------------------------------------

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'goals_opened');
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    final exercisesAsync = ref.watch(userExercisesProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Goals')),
      body: goalsAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
        error: (_, __) => Center(
          child: Text(
            'Unable to load goals. Please try again.',
            style: TextStyle(color: cs.error),
          ),
        ),
        data: (goals) {
          final exercises = exercisesAsync.valueOrNull ?? [];
          final completedIds = exercises
              .where((e) => e.status.isCompleted)
              .map((e) {
            if (e.subExercise != null) {
              return '${e.exerciseId}_${e.subExercise}';
            }
            return e.exerciseId;
          }).toSet();

          final totalCompleted = completedIds.length;
          final totalExercises = _fullPplIds.length;

          final firstSoloGoal = goals
              .where((g) => g.goalType == GoalType.firstSolo)
              .toList();
          final fullPplGoal = goals
              .where((g) => g.goalType == GoalType.fullPpl)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              // -- Motivational summary
              _MotivationalSummary(
                completed: totalCompleted,
                total: totalExercises,
              ),
              const SizedBox(height: 24),

              // -- First Solo goal
              _GoalCard(
                goalType: GoalType.firstSolo,
                existingGoal:
                    firstSoloGoal.isNotEmpty ? firstSoloGoal.first : null,
                completedIds: completedIds,
                targetIds: _firstSoloIds,
                icon: Icons.flight_takeoff_rounded,
              ),
              const SizedBox(height: 16),

              // -- Full PPL goal
              _GoalCard(
                goalType: GoalType.fullPpl,
                existingGoal:
                    fullPplGoal.isNotEmpty ? fullPplGoal.first : null,
                completedIds: completedIds,
                targetIds: _fullPplIds,
                icon: Icons.workspace_premium_rounded,
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motivational summary
// ---------------------------------------------------------------------------

class _MotivationalSummary extends StatelessWidget {
  final int completed;
  final int total;

  const _MotivationalSummary({
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final remaining = total - completed;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.emoji_events_rounded,
              color: AppColors.primary, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed exercise${completed == 1 ? '' : 's'} completed',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remaining > 0
                      ? '$remaining to go — keep flying!'
                      : 'All exercises completed!',
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Goal card
// ---------------------------------------------------------------------------

class _GoalCard extends ConsumerStatefulWidget {
  final GoalType goalType;
  final Goal? existingGoal;
  final Set<String> completedIds;
  final List<String> targetIds;
  final IconData icon;

  const _GoalCard({
    required this.goalType,
    required this.existingGoal,
    required this.completedIds,
    required this.targetIds,
    required this.icon,
  });

  @override
  ConsumerState<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends ConsumerState<_GoalCard> {
  bool _expanded = false;
  bool _saving = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(
      text: widget.existingGoal?.notes ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant _GoalCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.existingGoal?.notes != widget.existingGoal?.notes) {
      _notesController.text = widget.existingGoal?.notes ?? '';
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  int get _completedCount {
    return widget.targetIds
        .where((id) => widget.completedIds.contains(id))
        .length;
  }

  double get _progress {
    if (widget.targetIds.isEmpty) return 0;
    return _completedCount / widget.targetIds.length;
  }

  /// Determines status badge colour and label based on progress rate vs target.
  (String, Color) get _statusBadge {
    final goal = widget.existingGoal;
    if (goal == null) return ('Set Target', AppColors.onSurfaceVariant);
    if (goal.completed) return ('Completed', AppColors.success);

    final now = DateTime.now();
    final totalDays = goal.targetDate.difference(goal.createdAt).inDays;
    final elapsedDays = now.difference(goal.createdAt).inDays;

    if (now.isAfter(goal.targetDate)) return ('At Risk', AppColors.error);
    if (totalDays <= 0) return ('On Track', AppColors.success);

    final expectedProgress = elapsedDays / totalDays;
    final actualProgress = _progress;

    if (actualProgress >= expectedProgress * 0.85) {
      return ('On Track', AppColors.success);
    } else if (actualProgress >= expectedProgress * 0.5) {
      return ('Behind', AppColors.warning);
    } else {
      return ('At Risk', AppColors.error);
    }
  }

  int get _daysRemaining {
    final goal = widget.existingGoal;
    if (goal == null) return 0;
    return goal.targetDate.difference(DateTime.now()).inDays;
  }

  Future<void> _pickDate() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.existingGoal?.targetDate ??
          now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.primary,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;

    setState(() => _saving = true);
    try {
      if (widget.existingGoal != null) {
        await updateGoal(
          userId: uid,
          goalDocId: widget.existingGoal!.docId,
          targetDate: picked,
        );
      } else {
        await saveGoal(
          userId: uid,
          goalType: widget.goalType,
          targetDate: picked,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveNotes() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || widget.existingGoal == null) return;

    await updateGoal(
      userId: uid,
      goalDocId: widget.existingGoal!.docId,
      notes: _notesController.text,
    );
  }

  Future<void> _markComplete() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || widget.existingGoal == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Complete ${widget.existingGoal!.displayName}?'),
        content: const Text(
          'Mark this goal as completed? This is a huge achievement!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await completeGoal(userId: uid, goalDocId: widget.existingGoal!.docId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Congratulations! ${widget.existingGoal!.displayName} completed!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final goal = widget.existingGoal;
    final (statusLabel, statusColor) = _statusBadge;
    final goalName = widget.goalType == GoalType.firstSolo
        ? 'First Solo'
        : 'Full PPL Licence';

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: goal?.completed == true
            ? Border.all(color: AppColors.success.withValues(alpha: 0.5), width: 2)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(widget.icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goalName,
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (goal != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Target: ${DateFormat('d MMM yyyy').format(goal.targetDate)}',
                          style: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$_completedCount / ${widget.targetIds.length} exercises',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                    if (goal != null && !goal.completed)
                      Text(
                        _daysRemaining >= 0
                            ? '$_daysRemaining days remaining'
                            : '${-_daysRemaining} days overdue',
                        style: TextStyle(
                          color: _daysRemaining >= 0
                              ? cs.onSurface.withValues(alpha: 0.6)
                              : AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progress,
                    minHeight: 8,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.1),
                    color: goal?.completed == true
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Set/Change date
                TextButton.icon(
                  onPressed: _saving || goal?.completed == true
                      ? null
                      : _pickDate,
                  icon: Icon(
                    goal == null
                        ? Icons.calendar_today_rounded
                        : Icons.edit_calendar_rounded,
                    size: 18,
                  ),
                  label: Text(
                    goal == null ? 'Set Target Date' : 'Change Date',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const Spacer(),
                // Notes toggle
                if (goal != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _expanded = !_expanded),
                    icon: Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.notes_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _expanded ? 'Hide Notes' : 'Notes',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                // Mark complete
                if (goal != null && !goal.completed)
                  TextButton.icon(
                    onPressed: _markComplete,
                    icon: const Icon(Icons.check_circle_outline_rounded,
                        size: 18, color: AppColors.success),
                    label: const Text(
                      'Complete',
                      style: TextStyle(fontSize: 13, color: AppColors.success),
                    ),
                  ),
              ],
            ),
          ),

          // Expandable notes
          if (_expanded && goal != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    maxLength: InputSanitiser.maxMedium,
                    decoration: InputDecoration(
                      hintText: 'Add notes about this goal...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (_) {},
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _saveNotes,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Save Notes'),
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

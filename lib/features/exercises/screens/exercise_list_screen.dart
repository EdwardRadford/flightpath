// Exercise flight path journey map — visual serpentine path of all 19 CAA
// exercises with progress indicators, ratings, and sub-exercise branches.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

// ---------------------------------------------------------------------------
// Exercise data structure
// ---------------------------------------------------------------------------

class _ExerciseItem {
  final String exerciseId;
  final String name;
  final String shortName;
  final bool hasSubExercises;
  final List<({String subId, String subName})> subExercises;

  const _ExerciseItem({
    required this.exerciseId,
    required this.name,
    required this.shortName,
    this.hasSubExercises = false,
    this.subExercises = const [],
  });
}

const List<_ExerciseItem> _exercises = [
  _ExerciseItem(
    exerciseId: 'ex_01',
    name: 'Exercise 1 – Familiarisation with the Aeroplane',
    shortName: 'Familiarisation',
  ),
  _ExerciseItem(
    exerciseId: 'ex_02',
    name: 'Exercise 2 – Preparation for and Action after Flight',
    shortName: 'Pre/Post Flight',
  ),
  _ExerciseItem(
    exerciseId: 'ex_03',
    name: 'Exercise 3 – Air Experience',
    shortName: 'Air Experience',
  ),
  _ExerciseItem(
    exerciseId: 'ex_04',
    name: 'Exercise 4 – Effects of Controls',
    shortName: 'Effects of Controls',
  ),
  _ExerciseItem(
    exerciseId: 'ex_05',
    name: 'Exercise 5 – Taxiing',
    shortName: 'Taxiing',
  ),
  _ExerciseItem(
    exerciseId: 'ex_06',
    name: 'Exercise 6 – Straight and Level Flight',
    shortName: 'Straight & Level',
  ),
  _ExerciseItem(
    exerciseId: 'ex_07',
    name: 'Exercise 7 – Climbing',
    shortName: 'Climbing',
  ),
  _ExerciseItem(
    exerciseId: 'ex_08',
    name: 'Exercise 8 – Descending',
    shortName: 'Descending',
  ),
  _ExerciseItem(
    exerciseId: 'ex_09',
    name: 'Exercise 9 – Turning',
    shortName: 'Turning',
  ),
  _ExerciseItem(
    exerciseId: 'ex_10',
    name: 'Exercise 10 – Stalling & Slow Flight',
    shortName: 'Stalling & Slow Flight',
    hasSubExercises: true,
    subExercises: [
      (subId: '10a', subName: '10A – Slow Flight'),
      (subId: '10b', subName: '10B – Stalling'),
    ],
  ),
  _ExerciseItem(
    exerciseId: 'ex_11',
    name: 'Exercise 11 – Spin Awareness and Recovery',
    shortName: 'Spin Awareness',
  ),
  _ExerciseItem(
    exerciseId: 'ex_12',
    name: 'Exercise 12 – Take-off and Climb',
    shortName: 'Take-off & Climb',
  ),
  _ExerciseItem(
    exerciseId: 'ex_13',
    name: 'Exercise 13 – Circuit, Approach and Landing',
    shortName: 'Circuit & Landing',
  ),
  _ExerciseItem(
    exerciseId: 'ex_14',
    name: 'Exercise 14 – First Solo',
    shortName: 'First Solo',
  ),
  _ExerciseItem(
    exerciseId: 'ex_15',
    name: 'Exercise 15 – Advanced Turning',
    shortName: 'Advanced Turning',
  ),
  _ExerciseItem(
    exerciseId: 'ex_16',
    name: 'Exercise 16 – Forced Landing Without Power',
    shortName: 'Forced Landing',
  ),
  _ExerciseItem(
    exerciseId: 'ex_17',
    name: 'Exercise 17 – Precautionary Landing',
    shortName: 'Precautionary Landing',
  ),
  _ExerciseItem(
    exerciseId: 'ex_18',
    name: 'Exercise 18 – Navigation',
    shortName: 'Navigation',
    hasSubExercises: true,
    subExercises: [
      (subId: '18a', subName: '18A – Navigation'),
      (subId: '18b', subName: '18B – Nav at Lower Levels'),
      (subId: '18c', subName: '18C – Radio Navigation'),
    ],
  ),
  _ExerciseItem(
    exerciseId: 'ex_19',
    name: 'Exercise 19 – Night Flying (if applicable)',
    shortName: 'Night Flying',
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserExercise? _findExercise(
  List<UserExercise> list,
  String exerciseId, [
  String? subExerciseId,
]) {
  for (final ue in list) {
    if (ue.exerciseId != exerciseId) continue;
    if (subExerciseId == null && ue.subExercise == null) return ue;
    if (subExerciseId != null && ue.subExercise == subExerciseId) return ue;
  }
  return null;
}

/// Exercise status for visual display.
/// Green (mastered) only at 5 stars; completed but <5 shows as completed (amber).
enum _NodeStatus { notStarted, inProgress, completed, mastered }

_NodeStatus _nodeStatus(UserExercise? ue) {
  if (ue == null) return _NodeStatus.notStarted;
  switch (ue.status) {
    case ExerciseStatus.complete:
      return ue.bestRating == 5 ? _NodeStatus.mastered : _NodeStatus.completed;
    case ExerciseStatus.inProgress:
      return _NodeStatus.inProgress;
    case ExerciseStatus.notStarted:
      return _NodeStatus.notStarted;
  }
}

/// For exercises with sub-exercises, aggregate status.
_NodeStatus _aggregateStatus(
  List<UserExercise> list,
  String exerciseId,
  List<({String subId, String subName})> subs,
) {
  bool anyInProgress = false;
  bool allComplete = true;
  bool allMastered = true;
  for (final sub in subs) {
    final ue = _findExercise(list, exerciseId, sub.subId);
    final s = _nodeStatus(ue);
    if (s == _NodeStatus.mastered) {
      // good — both complete and mastered
    } else if (s == _NodeStatus.completed) {
      allMastered = false;
    } else {
      allComplete = false;
      allMastered = false;
      if (s == _NodeStatus.inProgress) anyInProgress = true;
    }
  }
  if (allComplete && allMastered) return _NodeStatus.mastered;
  if (allComplete) return _NodeStatus.completed;
  if (anyInProgress) return _NodeStatus.inProgress;
  // Check if any sub has been attempted at all
  for (final sub in subs) {
    final ue = _findExercise(list, exerciseId, sub.subId);
    if (ue != null && ue.ratingHistory.isNotEmpty) return _NodeStatus.inProgress;
  }
  return _NodeStatus.notStarted;
}

/// Best rating across sub-exercises.
int? _aggregateBestRating(
  List<UserExercise> list,
  String exerciseId,
  List<({String subId, String subName})> subs,
) {
  int? best;
  for (final sub in subs) {
    final ue = _findExercise(list, exerciseId, sub.subId);
    final r = ue?.bestRating;
    if (r != null && (best == null || r > best)) best = r;
  }
  return best;
}

String _exerciseNumberLabel(String exerciseId) {
  final parts = exerciseId.split('_');
  if (parts.length >= 2) {
    final num = int.tryParse(parts[1]);
    if (num != null) return '$num';
  }
  return exerciseId;
}

int _exerciseNumber(String exerciseId) {
  final parts = exerciseId.split('_');
  if (parts.length >= 2) return int.tryParse(parts[1]) ?? 0;
  return 0;
}

/// Find the index of the "current" exercise — the first in-progress or
/// not-started exercise.
int _findCurrentExerciseIndex(List<UserExercise> userExercises) {
  for (int i = 0; i < _exercises.length; i++) {
    final item = _exercises[i];
    final status = item.hasSubExercises
        ? _aggregateStatus(userExercises, item.exerciseId, item.subExercises)
        : _nodeStatus(_findExercise(userExercises, item.exerciseId));
    if (status == _NodeStatus.inProgress || status == _NodeStatus.notStarted) {
      return i;
    }
  }
  return _exercises.length - 1;
}

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const double _nodeRadius = 28.0;
const double _subNodeRadius = 18.0;
const double _verticalSpacing = 130.0;
const double _horizontalPadding = 48.0;
const double _subExerciseOffsetY = 54.0;
const double _subExerciseSpacingX = 70.0;

// ---------------------------------------------------------------------------
// ExerciseListScreen (public entry point — name kept for router compatibility)
// ---------------------------------------------------------------------------

class ExerciseListScreen extends ConsumerWidget {
  const ExerciseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(userExercisesProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isPremium = appUser?.isPremium ?? false;
    final currentExerciseNumber = appUser?.currentExerciseNumber ?? 1;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(
          children: [
            Icon(Icons.flight_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Flight Path',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: exercisesAsync.when(
        data: (userExercises) => _FlightPathBody(
          userExercises: userExercises,
          isPremium: isPremium,
          currentExerciseNumber: currentExerciseNumber,
        ),
        loading: () => const _LoadingBody(),
        error: (_, _) => const _ErrorBody(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main body with the flight path
// ---------------------------------------------------------------------------

class _FlightPathBody extends StatefulWidget {
  final List<UserExercise> userExercises;
  final bool isPremium;
  final int currentExerciseNumber;

  const _FlightPathBody({
    required this.userExercises,
    required this.isPremium,
    required this.currentExerciseNumber,
  });

  @override
  State<_FlightPathBody> createState() => _FlightPathBodyState();
}

class _FlightPathBodyState extends State<_FlightPathBody>
    with TickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _planeController;
  late final Animation<double> _planeAnimation;
  bool _didAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _planeAnimation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _planeController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pulseController.dispose();
    _planeController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoScroll) {
      _didAutoScroll = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent();
      });
    }
  }

  void _scrollToCurrent() {
    final currentIndex = _findCurrentExerciseIndex(widget.userExercises);
    final targetY = _topPadding + currentIndex * _verticalSpacing - 100;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetY.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  double get _topPadding => 24.0;

  /// Calculate the centre X for exercise at index, creating the serpentine.
  double _nodeCentreX(int index, double width) {
    final leftX = _horizontalPadding + _nodeRadius + 10;
    final rightX = width - _horizontalPadding - _nodeRadius - 10;
    // Alternate left/right
    return index.isEven ? leftX : rightX;
  }

  double _nodeCentreY(int index) {
    return _topPadding + index * _verticalSpacing + _nodeRadius;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final currentIndex = _findCurrentExerciseIndex(widget.userExercises);
    final totalHeight =
        _topPadding + _exercises.length * _verticalSpacing + 100;

    // Count completed exercises for progress header
    int completedCount = 0;
    for (final item in _exercises) {
      final status = item.hasSubExercises
          ? _aggregateStatus(
              widget.userExercises, item.exerciseId, item.subExercises)
          : _nodeStatus(_findExercise(widget.userExercises, item.exerciseId));
      if (status == _NodeStatus.completed || status == _NodeStatus.mastered) completedCount++;
    }

    // Check if any exercise has been started
    final bool noneStarted = widget.userExercises.isEmpty;

    return Column(
      children: [
        // Progress summary bar
        _ProgressHeader(
          completed: completedCount,
          total: _exercises.length,
        ),

        // Welcome banner when no exercises have been started
        if (noneStarted)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  color: AppColors.primary,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '19 exercises ahead \u2014 let\'s begin!',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap any exercise to start preparing.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: width,
              height: totalHeight,
              child: Stack(
                children: [
                  // The winding path line (decorative, exclude from semantics)
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: _FlightPathPainter(
                          exercises: _exercises,
                          userExercises: widget.userExercises,
                          nodeXCalculator: (i) => _nodeCentreX(i, width),
                          nodeYCalculator: _nodeCentreY,
                          currentIndex: currentIndex,
                        ),
                      ),
                    ),
                  ),
                  // Exercise nodes
                  for (int i = 0; i < _exercises.length; i++)
                    ..._buildExerciseNode(i, width, currentIndex),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildExerciseNode(
      int index, double width, int currentIndex) {
    final item = _exercises[index];
    final cx = _nodeCentreX(index, width);
    final cy = _nodeCentreY(index);
    final isCurrent = index == currentIndex;
    final exNum = _exerciseNumber(item.exerciseId);

    final status = item.hasSubExercises
        ? _aggregateStatus(
            widget.userExercises, item.exerciseId, item.subExercises)
        : _nodeStatus(_findExercise(widget.userExercises, item.exerciseId));

    final bestRating = item.hasSubExercises
        ? _aggregateBestRating(
            widget.userExercises, item.exerciseId, item.subExercises)
        : _findExercise(widget.userExercises, item.exerciseId)?.bestRating;

    final freeStart = math.max(1, widget.currentExerciseNumber - 2);
    final freeEnd = math.min(19, widget.currentExerciseNumber + 2);
    final showPro = !widget.isPremium && (exNum < freeStart || exNum > freeEnd);
    final isLeft = index.isEven;

    // Label positioning
    final labelWidth = width * 0.42;
    final labelLeft =
        isLeft ? cx + _nodeRadius + 14 : cx - _nodeRadius - 14 - labelWidth;

    final widgets = <Widget>[];

    // Pulsing glow ring for current exercise
    if (isCurrent) {
      widgets.add(
        Positioned(
          left: cx - _nodeRadius - 8,
          top: cy - _nodeRadius - 8,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: (_nodeRadius + 8) * 2,
                height: (_nodeRadius + 8) * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary
                        .withValues(alpha: 0.4 + 0.4 * _pulseAnimation.value),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.15 + 0.2 * _pulseAnimation.value),
                      blurRadius: 16 + 10 * _pulseAnimation.value,
                      spreadRadius: 2 + 6 * _pulseAnimation.value,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Small plane icon hovering above the current node
      widgets.add(
        Positioned(
          left: cx - 12,
          top: cy - _nodeRadius - 30,
          child: AnimatedBuilder(
            animation: _planeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _planeAnimation.value),
                child: Icon(
                  Icons.flight_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              );
            },
          ),
        ),
      );
    }

    // Main node circle with Hero animation
    final String statusLabel = switch (status) {
      _NodeStatus.mastered => 'mastered',
      _NodeStatus.completed => 'completed',
      _NodeStatus.inProgress => 'in progress',
      _NodeStatus.notStarted => 'not started',
    };
    widgets.add(
      Positioned(
        left: cx - _nodeRadius,
        top: cy - _nodeRadius,
        child: Semantics(
          button: true,
          label: 'Exercise ${_exerciseNumberLabel(item.exerciseId)}, '
              '${item.shortName}, $statusLabel'
              '${isCurrent ? ', current exercise' : ''}',
          child: GestureDetector(
            onTap: () => _onExerciseTap(item),
            child: Hero(
              tag: 'exercise_node_${item.exerciseId}',
              child: _ExerciseNodeCircle(
                label: _exerciseNumberLabel(item.exerciseId),
                status: status,
                isCurrent: isCurrent,
                radius: _nodeRadius,
              ),
            ),
          ),
        ),
      ),
    );

    // PRO badge
    if (showPro) {
      widgets.add(
        Positioned(
          left: cx + _nodeRadius - 14,
          top: cy - _nodeRadius - 4,
          child: _ProBadge(),
        ),
      );
    }

    // Exercise label card
    widgets.add(
      Positioned(
        left: labelLeft,
        top: cy - 22,
        width: labelWidth,
        child: GestureDetector(
          onTap: () => _onExerciseTap(item),
          child: _ExerciseLabel(
            shortName: item.shortName,
            status: status,
            bestRating: bestRating,
            isLeft: isLeft,
            isMilestone: exNum == 14,
          ),
        ),
      ),
    );

    // Sub-exercise branch nodes
    if (item.hasSubExercises) {
      final subNodes = _buildSubExerciseNodes(
        item,
        cx,
        cy,
        isLeft,
        width,
      );
      widgets.addAll(subNodes);
    }

    return widgets;
  }

  List<Widget> _buildSubExerciseNodes(
    _ExerciseItem item,
    double cx,
    double cy,
    bool parentIsLeft,
    double screenWidth,
  ) {
    final widgets = <Widget>[];
    final subCount = item.subExercises.length;

    for (int si = 0; si < subCount; si++) {
      final sub = item.subExercises[si];
      final ue =
          _findExercise(widget.userExercises, item.exerciseId, sub.subId);
      final subStatus = _nodeStatus(ue);

      // Position sub-nodes below and spreading out from the parent
      final offsetX = (si - (subCount - 1) / 2) * _subExerciseSpacingX;
      final subCx = cx + offsetX;
      final subCy = cy + _subExerciseOffsetY;

      widgets.add(
        Positioned(
          left: subCx - _subNodeRadius,
          top: subCy - _subNodeRadius,
          child: GestureDetector(
            onTap: () {
              context.push('/exercises/${item.exerciseId}_${sub.subId}');
            },
            child: _ExerciseNodeCircle(
              label: sub.subId.toUpperCase(),
              status: subStatus,
              isCurrent: false,
              radius: _subNodeRadius,
              fontSize: 9,
            ),
          ),
        ),
      );

      // Sub-exercise label
      widgets.add(
        Positioned(
          left: subCx - 38,
          top: subCy + _subNodeRadius + 4,
          width: 76,
          child: GestureDetector(
            onTap: () {
              context.push('/exercises/${item.exerciseId}_${sub.subId}');
            },
            child: Text(
              sub.subName.split(' – ').last,
              style: TextStyle(
                color: (subStatus == _NodeStatus.completed || subStatus == _NodeStatus.mastered)
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
                fontSize: 9,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  void _onExerciseTap(_ExerciseItem item) {
    if (item.hasSubExercises) {
      // Navigate to first sub-exercise
      context.push(
          '/exercises/${item.exerciseId}_${item.subExercises.first.subId}');
    } else {
      context.push('/exercises/${item.exerciseId}');
    }
  }
}

// ---------------------------------------------------------------------------
// Progress header
// ---------------------------------------------------------------------------

class _ProgressHeader extends StatelessWidget {
  final int completed;
  final int total;

  const _ProgressHeader({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int progressPercent = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.route_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Journey',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.onSurfaceDark
                            : AppColors.onSurfaceLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$completed / $total exercises',
                      style: TextStyle(
                        color: isDark
                            ? AppColors.onSurfaceVariantDark
                            : AppColors.onSurfaceVariantLight,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Semantics(
                  label: 'Progress: $progressPercent percent, $completed of $total exercises completed',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(AppColors.success),
                    ),
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
// AnimatedBuilder helper (uses AnimatedWidget pattern)
// ---------------------------------------------------------------------------

class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}

// ---------------------------------------------------------------------------
// Exercise label widget (name + stars/status)
// ---------------------------------------------------------------------------

class _ExerciseLabel extends StatelessWidget {
  final String shortName;
  final _NodeStatus status;
  final int? bestRating;
  final bool isLeft;
  final bool isMilestone;

  const _ExerciseLabel({
    required this.shortName,
    required this.status,
    required this.bestRating,
    required this.isLeft,
    this.isMilestone = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment:
          isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment:
              isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isMilestone && !isLeft) ...[
              Icon(Icons.emoji_events_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                shortName,
                style: TextStyle(
                  color: (status == _NodeStatus.completed || status == _NodeStatus.mastered)
                      ? (isDark
                          ? AppColors.onSurfaceDark
                          : AppColors.onSurfaceLight)
                      : (isDark
                          ? AppColors.onSurfaceVariantDark
                          : AppColors.onSurfaceVariantLight),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: isLeft ? TextAlign.left : TextAlign.right,
              ),
            ),
            if (isMilestone && isLeft) ...[
              const SizedBox(width: 3),
              Icon(Icons.emoji_events_rounded,
                  color: AppColors.warning, size: 14),
            ],
          ],
        ),
        const SizedBox(height: 3),
        _MiniRatingStars(
          bestRating: bestRating,
          status: status,
          alignment:
              isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise node circle
// ---------------------------------------------------------------------------

class _ExerciseNodeCircle extends StatelessWidget {
  final String label;
  final _NodeStatus status;
  final bool isCurrent;
  final double radius;
  final double? fontSize;

  const _ExerciseNodeCircle({
    required this.label,
    required this.status,
    required this.isCurrent,
    required this.radius,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color fillColor;
    Color borderColor;
    Widget? overlay;

    switch (status) {
      case _NodeStatus.mastered:
        fillColor = AppColors.success;
        borderColor = AppColors.success;
        overlay = Icon(
          Icons.star_rounded,
          color: Colors.white,
          size: radius * 0.7,
        );
      case _NodeStatus.completed:
        fillColor = AppColors.warning;
        borderColor = AppColors.warning;
        overlay = Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: radius * 0.7,
        );
      case _NodeStatus.inProgress:
        fillColor = AppColors.primary;
        borderColor = AppColors.primary;
        overlay = null;
      case _NodeStatus.notStarted:
        fillColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
        borderColor = isDark
            ? AppColors.onSurfaceVariantDark.withValues(alpha: 0.3)
            : AppColors.onSurfaceVariantLight.withValues(alpha: 0.3);
        overlay = null;
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillColor,
        border: Border.all(color: borderColor, width: 2.5),
        boxShadow: status != _NodeStatus.notStarted
            ? [
                BoxShadow(
                  color: borderColor.withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: overlay ??
            Text(
              label,
              style: TextStyle(
                color: status == _NodeStatus.notStarted
                    ? (isDark
                        ? AppColors.onSurfaceVariantDark
                        : AppColors.onSurfaceVariantLight)
                    : Colors.white,
                fontSize: fontSize ?? (label.length > 2 ? 11 : 14),
                fontWeight: FontWeight.w700,
              ),
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PRO badge
// ---------------------------------------------------------------------------

class _ProBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'PRO',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mini rating stars
// ---------------------------------------------------------------------------

class _MiniRatingStars extends StatelessWidget {
  final int? bestRating;
  final _NodeStatus status;
  final MainAxisAlignment alignment;

  const _MiniRatingStars({
    required this.bestRating,
    required this.status,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (bestRating == null) {
      String label;
      switch (status) {
        case _NodeStatus.mastered:
          label = 'Mastered';
        case _NodeStatus.inProgress:
          label = 'In progress';
        case _NodeStatus.completed:
          label = 'Completed';
        case _NodeStatus.notStarted:
          label = 'Not started';
      }
      return Text(
        label,
        style: TextStyle(
          color: status == _NodeStatus.inProgress
              ? AppColors.primary
              : (isDark
                  ? AppColors.onSurfaceVariantDark.withValues(alpha: 0.6)
                  : AppColors.onSurfaceVariantLight.withValues(alpha: 0.6)),
          fontSize: 10,
        ),
      );
    }

    return Semantics(
      label: 'Best rating: $bestRating out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: alignment,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            return Icon(
              (i + 1) <= bestRating!
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              color: AppColors.success,
              size: 12,
            );
          }),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Custom painter for the winding flight path
// ---------------------------------------------------------------------------

class _FlightPathPainter extends CustomPainter {
  final List<_ExerciseItem> exercises;
  final List<UserExercise> userExercises;
  final double Function(int) nodeXCalculator;
  final double Function(int) nodeYCalculator;
  final int currentIndex;

  _FlightPathPainter({
    required this.exercises,
    required this.userExercises,
    required this.nodeXCalculator,
    required this.nodeYCalculator,
    required this.currentIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw the main serpentine path
    _drawMainPath(canvas, size);

    // Draw sub-exercise branches
    for (int i = 0; i < exercises.length; i++) {
      if (exercises[i].hasSubExercises) {
        _drawSubExerciseBranches(canvas, i);
      }
    }

    // Draw cloud decorations
    _drawClouds(canvas, size);
  }

  void _drawMainPath(Canvas canvas, Size size) {
    if (exercises.length < 2) return;

    for (int i = 0; i < exercises.length - 1; i++) {
      final startX = nodeXCalculator(i);
      final startY = nodeYCalculator(i);
      final endX = nodeXCalculator(i + 1);
      final endY = nodeYCalculator(i + 1);

      // Determine if this segment is completed
      final item = exercises[i];
      final status = item.hasSubExercises
          ? _aggregateStatus(userExercises, item.exerciseId, item.subExercises)
          : _nodeStatus(_findExercise(userExercises, item.exerciseId));
      final isCompleted = status == _NodeStatus.completed || status == _NodeStatus.mastered;

      // Build a curved path between nodes
      final path = Path();
      path.moveTo(startX, startY);

      // S-curve between nodes
      final midY = (startY + endY) / 2;
      path.cubicTo(
        startX, midY,
        endX, midY,
        endX, endY,
      );

      if (isCompleted) {
        // Solid path for completed segments with glow
        final glowPaint = Paint()
          ..color = AppColors.primary.withValues(alpha: 0.15)
          ..strokeWidth = 8.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, glowPaint);

        final completedPaint = Paint()
          ..color = AppColors.primary
          ..strokeWidth = 3.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(path, completedPaint);
      } else {
        // Dashed grey line for incomplete segments
        _drawDashedPath(canvas, path, _incompletePaint());
      }
    }
  }

  void _drawSubExerciseBranches(Canvas canvas, int parentIndex) {
    final item = exercises[parentIndex];
    final cx = nodeXCalculator(parentIndex);
    final cy = nodeYCalculator(parentIndex);
    final subCount = item.subExercises.length;

    for (int si = 0; si < subCount; si++) {
      final sub = item.subExercises[si];
      final ue = _findExercise(userExercises, item.exerciseId, sub.subId);
      final subStatus = _nodeStatus(ue);

      final offsetX = (si - (subCount - 1) / 2) * _subExerciseSpacingX;
      final subCx = cx + offsetX;
      final subCy = cy + _subExerciseOffsetY;

      final branchPath = Path();
      branchPath.moveTo(cx, cy + _nodeRadius);
      branchPath.quadraticBezierTo(
        cx, subCy - 10,
        subCx, subCy - _subNodeRadius,
      );

      if (subStatus == _NodeStatus.completed || subStatus == _NodeStatus.mastered) {
        final completedPaint = Paint()
          ..color = AppColors.success.withValues(alpha: 0.6)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(branchPath, completedPaint);
      } else {
        _drawDashedPath(canvas, branchPath, _incompletePaint(width: 1.5));
      }
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    // Draw subtle cloud shapes at various positions for atmosphere
    final cloudPaint = Paint()
      ..color = AppColors.onSurfaceVariantDark.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final cloudPositions = [
      Offset(size.width * 0.15, 80),
      Offset(size.width * 0.85, 350),
      Offset(size.width * 0.2, 650),
      Offset(size.width * 0.8, 950),
      Offset(size.width * 0.1, 1300),
      Offset(size.width * 0.9, 1600),
      Offset(size.width * 0.3, 1950),
    ];

    for (final pos in cloudPositions) {
      if (pos.dy > size.height) continue;
      _drawCloud(canvas, pos, cloudPaint);
    }
  }

  void _drawCloud(Canvas canvas, Offset center, Paint paint) {
    // Simple cloud made of overlapping circles
    canvas.drawCircle(center, 16, paint);
    canvas.drawCircle(Offset(center.dx - 12, center.dy + 4), 12, paint);
    canvas.drawCircle(Offset(center.dx + 14, center.dy + 3), 13, paint);
    canvas.drawCircle(Offset(center.dx + 6, center.dy - 6), 11, paint);
    canvas.drawCircle(Offset(center.dx - 5, center.dy + 8), 10, paint);
  }

  Paint _incompletePaint({double width = 2.5}) {
    return Paint()
      ..color = AppColors.onSurfaceVariantDark.withValues(alpha: 0.2)
      ..strokeWidth = width
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      const dashLength = 6.0;
      const gapLength = 6.0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        final end = (distance + length).clamp(0.0, metric.length);
        if (draw) {
          final segment = metric.extractPath(distance, end);
          canvas.drawPath(segment, paint);
        }
        distance = end;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(_FlightPathPainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex ||
        oldDelegate.userExercises != userExercises;
  }
}

// ---------------------------------------------------------------------------
// Loading state
// ---------------------------------------------------------------------------

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.primary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorBody extends StatelessWidget {
  const _ErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: 40,
            ),
            const SizedBox(height: 16),
             Text(
              'Could not load exercises',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
             Text(
              'Unable to load exercises. Please check your connection and try again.',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

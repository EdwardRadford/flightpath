import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

// ---------------------------------------------------------------------------
// Exercise data structure (file-level — consumed by FlightPathBody and painter)
// ---------------------------------------------------------------------------

class ExerciseListItem {
  final String exerciseId;
  final String name;
  final String shortName;
  final bool hasSubExercises;
  final bool isMilestone;
  final List<({String subId, String subName})> subExercises;

  const ExerciseListItem({
    required this.exerciseId,
    required this.name,
    required this.shortName,
    this.hasSubExercises = false,
    this.isMilestone = false,
    this.subExercises = const [],
  });
}

const List<ExerciseListItem> kExercises = [
  ExerciseListItem(
    exerciseId: 'ex_01',
    name: 'Exercise 1 \u2013 Familiarisation with the Aeroplane',
    shortName: 'Familiarisation',
  ),
  ExerciseListItem(
    exerciseId: 'ex_02',
    name: 'Exercise 2 \u2013 Preparation for and Action after Flight',
    shortName: 'Pre/Post Flight',
  ),
  ExerciseListItem(
    exerciseId: 'ex_03',
    name: 'Exercise 3 \u2013 Air Experience',
    shortName: 'Air Experience',
  ),
  ExerciseListItem(
    exerciseId: 'ex_04',
    name: 'Exercise 4 \u2013 Effects of Controls',
    shortName: 'Effects of Controls',
  ),
  ExerciseListItem(
    exerciseId: 'ex_05',
    name: 'Exercise 5 \u2013 Taxiing',
    shortName: 'Taxiing',
  ),
  ExerciseListItem(
    exerciseId: 'ex_06',
    name: 'Exercise 6 \u2013 Straight and Level Flight',
    shortName: 'Straight & Level',
  ),
  ExerciseListItem(
    exerciseId: 'ex_07',
    name: 'Exercise 7 \u2013 Climbing',
    shortName: 'Climbing',
  ),
  ExerciseListItem(
    exerciseId: 'ex_08',
    name: 'Exercise 8 \u2013 Descending',
    shortName: 'Descending',
  ),
  ExerciseListItem(
    exerciseId: 'ex_09',
    name: 'Exercise 9 \u2013 Turning',
    shortName: 'Turning',
  ),
  ExerciseListItem(
    exerciseId: 'ex_10',
    name: 'Exercise 10 \u2013 Stalling & Slow Flight',
    shortName: 'Stalling & Slow Flight',
    hasSubExercises: true,
    subExercises: [
      (subId: '10a', subName: '10A \u2013 Slow Flight'),
      (subId: '10b', subName: '10B \u2013 Stalling'),
    ],
  ),
  ExerciseListItem(
    exerciseId: 'ex_11',
    name: 'Exercise 11 \u2013 Spin Awareness and Recovery',
    shortName: 'Spin Awareness',
  ),
  ExerciseListItem(
    exerciseId: 'ex_12',
    name: 'Exercise 12 \u2013 Take-off and Climb',
    shortName: 'Take-off & Climb',
  ),
  ExerciseListItem(
    exerciseId: 'ex_13',
    name: 'Exercise 13 \u2013 Circuit, Approach and Landing',
    shortName: 'Circuit & Landing',
  ),
  ExerciseListItem(
    exerciseId: 'ex_14',
    name: 'Exercise 14 \u2013 First Solo',
    shortName: 'First Solo',
    isMilestone: true,
  ),
  ExerciseListItem(
    exerciseId: 'ex_15',
    name: 'Exercise 15 \u2013 Advanced Turning',
    shortName: 'Advanced Turning',
  ),
  ExerciseListItem(
    exerciseId: 'ex_16',
    name: 'Exercise 16 \u2013 Forced Landing Without Power',
    shortName: 'Forced Landing',
  ),
  ExerciseListItem(
    exerciseId: 'ex_17',
    name: 'Exercise 17 \u2013 Precautionary Landing',
    shortName: 'Precautionary Landing',
  ),
  ExerciseListItem(
    exerciseId: 'ex_18',
    name: 'Exercise 18 \u2013 Navigation',
    shortName: 'Navigation',
    hasSubExercises: true,
    subExercises: [
      (subId: '18a', subName: '18A \u2013 Navigation'),
      (subId: '18b', subName: '18B \u2013 Nav at Lower Levels'),
      (subId: '18c', subName: '18C \u2013 Radio Navigation'),
    ],
  ),
  ExerciseListItem(
    exerciseId: 'ex_19',
    name: 'Exercise 19 \u2013 Night Flying (if applicable)',
    shortName: 'Night Flying',
  ),
];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

UserExercise? findExerciseInList(
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

enum NodeStatus { notStarted, inProgress, completed, mastered }

NodeStatus nodeStatus(UserExercise? ue) {
  if (ue == null) return NodeStatus.notStarted;
  switch (ue.status) {
    case ExerciseStatus.completedUnsatisfactory:
    case ExerciseStatus.completedSatisfactory:
      return ue.bestRating == 5
          ? NodeStatus.mastered
          : NodeStatus.completed;
    case ExerciseStatus.inProgress:
      return NodeStatus.inProgress;
    case ExerciseStatus.notStarted:
      return NodeStatus.notStarted;
  }
}

NodeStatus aggregateStatus(
  List<UserExercise> list,
  String exerciseId,
  List<({String subId, String subName})> subs,
) {
  bool anyInProgress = false;
  bool allComplete = true;
  bool allMastered = true;
  for (final sub in subs) {
    final ue = findExerciseInList(list, exerciseId, sub.subId);
    final s = nodeStatus(ue);
    if (s == NodeStatus.mastered) {
      // good
    } else if (s == NodeStatus.completed) {
      allMastered = false;
    } else {
      allComplete = false;
      allMastered = false;
      if (s == NodeStatus.inProgress) anyInProgress = true;
    }
  }
  if (allComplete && allMastered) return NodeStatus.mastered;
  if (allComplete) return NodeStatus.completed;
  if (anyInProgress) return NodeStatus.inProgress;
  for (final sub in subs) {
    final ue = findExerciseInList(list, exerciseId, sub.subId);
    if (ue != null && ue.ratingHistory.isNotEmpty) {
      return NodeStatus.inProgress;
    }
  }
  return NodeStatus.notStarted;
}

int? aggregateBestRating(
  List<UserExercise> list,
  String exerciseId,
  List<({String subId, String subName})> subs,
) {
  int? best;
  for (final sub in subs) {
    final ue = findExerciseInList(list, exerciseId, sub.subId);
    final r = ue?.bestRating;
    if (r != null && (best == null || r > best)) best = r;
  }
  return best;
}

String exerciseNumberLabel(String exerciseId) {
  final parts = exerciseId.split('_');
  if (parts.length >= 2) {
    final num = int.tryParse(parts[1]);
    if (num != null) return '$num';
  }
  return exerciseId;
}

int exerciseNumber(String exerciseId) {
  final parts = exerciseId.split('_');
  if (parts.length >= 2) return int.tryParse(parts[1]) ?? 0;
  return 0;
}

int findCurrentExerciseIndex(List<UserExercise> userExercises) {
  for (int i = 0; i < kExercises.length; i++) {
    final item = kExercises[i];
    final status = item.hasSubExercises
        ? aggregateStatus(
            userExercises, item.exerciseId, item.subExercises)
        : nodeStatus(findExerciseInList(userExercises, item.exerciseId));
    if (status == NodeStatus.inProgress ||
        status == NodeStatus.notStarted) {
      return i;
    }
  }
  return kExercises.length - 1;
}

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------

const double kNodeRadius = 28.0;
const double kSubNodeRadius = 18.0;
const double kVerticalSpacing = 130.0;
const double kHorizontalPadding = 48.0;
const double kSubExerciseOffsetY = 54.0;
const double kSubExerciseSpacingX = 80.0;

// Returns the X centre for sub-exercise [si] of [subCount], given the parent
// centre [parentCx] and canvas [screenWidth]. For 3+ subs the cluster shifts
// inward so all nodes AND their labels (76px wide) remain on-screen.
double _computeSubCx(
    double parentCx, int si, int subCount, double screenWidth) {
  final spacing = subCount > 2 ? 100.0 : kSubExerciseSpacingX;
  final halfSpan = (subCount - 1) / 2 * spacing;
  // Shrink cluster centre so the outermost label edges sit 4px inside screen.
  const labelHalfWidth = 38.0;
  final minCx = kSubNodeRadius + 4.0 + halfSpan + labelHalfWidth;
  final maxCx = screenWidth - kSubNodeRadius - 4.0 - halfSpan - labelHalfWidth;
  final clusterCx = parentCx.clamp(minCx, maxCx);
  return clusterCx + (si - (subCount - 1) / 2) * spacing;
}

// ---------------------------------------------------------------------------
// FlightPathBody
// ---------------------------------------------------------------------------

class FlightPathBody extends StatefulWidget {
  final List<UserExercise> userExercises;
  final bool isPremium;
  final int currentExerciseNumber;

  const FlightPathBody({
    super.key,
    required this.userExercises,
    required this.isPremium,
    required this.currentExerciseNumber,
  });

  @override
  State<FlightPathBody> createState() => _FlightPathBodyState();
}

class _FlightPathBodyState extends State<FlightPathBody>
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
    final currentIndex = findCurrentExerciseIndex(widget.userExercises);
    final targetY = _topPadding + currentIndex * kVerticalSpacing - 100;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetY.clamp(
            0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  double get _topPadding => 24.0;

  double _nodeCentreX(int index, double width) {
    final leftX = kHorizontalPadding + kNodeRadius + 10;
    final rightX = width - kHorizontalPadding - kNodeRadius - 10;
    return index.isEven ? leftX : rightX;
  }

  double _nodeCentreY(int index) {
    return _topPadding + index * kVerticalSpacing + kNodeRadius;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final currentIndex = findCurrentExerciseIndex(widget.userExercises);
    final totalHeight =
        _topPadding + kExercises.length * kVerticalSpacing + 100;

    int completedCount = 0;
    for (final item in kExercises) {
      final status = item.hasSubExercises
          ? aggregateStatus(
              widget.userExercises, item.exerciseId, item.subExercises)
          : nodeStatus(
              findExerciseInList(widget.userExercises, item.exerciseId));
      if (status == NodeStatus.completed || status == NodeStatus.mastered) {
        completedCount++;
      }
    }

    final bool noneStarted = widget.userExercises.isEmpty;

    return Column(
      children: [
        ExerciseListProgressHeader(
          completed: completedCount,
          total: kExercises.length,
        ),

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
                const Icon(
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
                  Positioned.fill(
                    child: ExcludeSemantics(
                      child: CustomPaint(
                        painter: FlightPathPainter(
                          exercises: kExercises,
                          userExercises: widget.userExercises,
                          nodeXCalculator: (i) => _nodeCentreX(i, width),
                          nodeYCalculator: _nodeCentreY,
                          currentIndex: currentIndex,
                        ),
                      ),
                    ),
                  ),
                  for (int i = 0; i < kExercises.length; i++)
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
    final item = kExercises[index];
    final cx = _nodeCentreX(index, width);
    final cy = _nodeCentreY(index);
    final isCurrent = index == currentIndex;
    final exNum = exerciseNumber(item.exerciseId);

    final status = item.hasSubExercises
        ? aggregateStatus(
            widget.userExercises, item.exerciseId, item.subExercises)
        : nodeStatus(
            findExerciseInList(widget.userExercises, item.exerciseId));

    final bestRating = item.hasSubExercises
        ? aggregateBestRating(
            widget.userExercises, item.exerciseId, item.subExercises)
        : findExerciseInList(widget.userExercises, item.exerciseId)
            ?.bestRating;

    final freeStart =
        math.max(1, widget.currentExerciseNumber - 2);
    final freeEnd =
        math.min(kExercises.length, widget.currentExerciseNumber + 2);
    final showPro =
        !widget.isPremium && (exNum < freeStart || exNum > freeEnd);
    final isLeft = index.isEven;

    final labelWidth = width * 0.42;
    final labelLeft = isLeft
        ? cx + kNodeRadius + 14
        : cx - kNodeRadius - 14 - labelWidth;

    final widgets = <Widget>[];

    if (isCurrent) {
      widgets.add(
        Positioned(
          left: cx - kNodeRadius - 8,
          top: cy - kNodeRadius - 8,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: (kNodeRadius + 8) * 2,
                height: (kNodeRadius + 8) * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(
                        alpha: 0.4 + 0.4 * _pulseAnimation.value),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(
                          alpha: 0.15 + 0.2 * _pulseAnimation.value),
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

      widgets.add(
        Positioned(
          left: cx - 12,
          top: cy - kNodeRadius - 30,
          child: AnimatedBuilder(
            animation: _planeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _planeAnimation.value),
                child: const Icon(
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

    final String statusLabel = switch (status) {
      NodeStatus.mastered => 'mastered',
      NodeStatus.completed => 'completed',
      NodeStatus.inProgress => 'in progress',
      NodeStatus.notStarted => 'not started',
    };
    widgets.add(
      Positioned(
        left: cx - kNodeRadius,
        top: cy - kNodeRadius,
        child: Semantics(
          button: true,
          label: 'Exercise ${exerciseNumberLabel(item.exerciseId)}, '
              '${item.shortName}, $statusLabel'
              '${isCurrent ? ', current exercise' : ''}',
          child: GestureDetector(
            onTap: () => _onExerciseTap(item),
            child: Hero(
              tag: 'exercise_node_${item.exerciseId}',
              child: ExerciseNodeCircle(
                label: exerciseNumberLabel(item.exerciseId),
                status: status,
                isCurrent: isCurrent,
                radius: kNodeRadius,
              ),
            ),
          ),
        ),
      ),
    );

    if (showPro) {
      widgets.add(
        Positioned(
          left: cx + kNodeRadius - 14,
          top: cy - kNodeRadius - 4,
          child: const ExerciseListProBadge(),
        ),
      );
      widgets.add(
        Positioned(
          left: cx - kNodeRadius,
          top: cy - kNodeRadius,
          child: IgnorePointer(
            child: Container(
              width: kNodeRadius * 2,
              height: kNodeRadius * 2,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x66000000),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    widgets.add(
      Positioned(
        left: labelLeft,
        top: cy - 22,
        width: labelWidth,
        child: GestureDetector(
          onTap: () => _onExerciseTap(item),
          child: ExerciseNodeLabel(
            shortName: item.shortName,
            status: status,
            bestRating: bestRating,
            isLeft: isLeft,
            isMilestone: item.isMilestone,
          ),
        ),
      ),
    );

    if (item.hasSubExercises) {
      final subNodes =
          _buildSubExerciseNodes(item, cx, cy, isLeft, width);
      widgets.addAll(subNodes);
    }

    return widgets;
  }

  List<Widget> _buildSubExerciseNodes(
    ExerciseListItem item,
    double cx,
    double cy,
    bool parentIsLeft,
    double screenWidth,
  ) {
    final widgets = <Widget>[];
    final subCount = item.subExercises.length;

    for (int si = 0; si < subCount; si++) {
      final sub = item.subExercises[si];
      final ue = findExerciseInList(
          widget.userExercises, item.exerciseId, sub.subId);
      final subStatus = nodeStatus(ue);

      final subCx = _computeSubCx(cx, si, subCount, screenWidth);
      final subCy = cy + kSubExerciseOffsetY;

      widgets.add(
        Positioned(
          left: subCx - kSubNodeRadius,
          top: subCy - kSubNodeRadius,
          child: GestureDetector(
            onTap: () {
              context.push('/exercises/${item.exerciseId}_${sub.subId}');
            },
            child: ExerciseNodeCircle(
              label: sub.subId.toUpperCase(),
              status: subStatus,
              isCurrent: false,
              radius: kSubNodeRadius,
              fontSize: 9,
            ),
          ),
        ),
      );

      widgets.add(
        Positioned(
          left: subCx - 38,
          top: subCy + kSubNodeRadius + 4,
          width: 76,
          child: GestureDetector(
            onTap: () {
              context.push('/exercises/${item.exerciseId}_${sub.subId}');
            },
            child: Text(
              sub.subName.split(' \u2013 ').last,
              style: TextStyle(
                color: (subStatus == NodeStatus.completed ||
                        subStatus == NodeStatus.mastered)
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

  void _onExerciseTap(ExerciseListItem item) {
    if (!widget.isPremium) {
      final exNum = int.tryParse(item.exerciseId.replaceFirst('ex_', '')) ?? 0;
      final freeStart = math.max(1, widget.currentExerciseNumber - 2);
      final freeEnd = math.min(kExercises.length, widget.currentExerciseNumber + 2);
      if (exNum < freeStart || exNum > freeEnd) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upgrade to Pro to unlock all 22 exercises'),
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }
    }
    if (item.hasSubExercises) {
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

class ExerciseListProgressHeader extends StatelessWidget {
  final int completed;
  final int total;

  const ExerciseListProgressHeader({
    super.key,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int progressPercent = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isDark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
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
                  label:
                      'Progress: $progressPercent percent, $completed of $total exercises completed',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 5,
                      backgroundColor: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.success),
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
// Exercise label widget
// ---------------------------------------------------------------------------

class ExerciseNodeLabel extends StatelessWidget {
  final String shortName;
  final NodeStatus status;
  final int? bestRating;
  final bool isLeft;
  final bool isMilestone;

  const ExerciseNodeLabel({
    super.key,
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
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.warning, size: 14),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                shortName,
                style: TextStyle(
                  color: (status == NodeStatus.completed ||
                          status == NodeStatus.mastered)
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
              const Icon(Icons.emoji_events_rounded,
                  color: AppColors.warning, size: 14),
            ],
          ],
        ),
        const SizedBox(height: 3),
        ExerciseMiniRatingStars(
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

class ExerciseNodeCircle extends StatelessWidget {
  final String label;
  final NodeStatus status;
  final bool isCurrent;
  final double radius;
  final double? fontSize;

  const ExerciseNodeCircle({
    super.key,
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
      case NodeStatus.mastered:
        fillColor = AppColors.success;
        borderColor = AppColors.success;
        overlay = Icon(
          Icons.star_rounded,
          color: Colors.white,
          size: radius * 0.7,
        );
      case NodeStatus.completed:
        fillColor = AppColors.warning;
        borderColor = AppColors.warning;
        overlay = Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: radius * 0.7,
        );
      case NodeStatus.inProgress:
        fillColor = AppColors.primary;
        borderColor = AppColors.primary;
        overlay = null;
      case NodeStatus.notStarted:
        fillColor = isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight;
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
        boxShadow: status != NodeStatus.notStarted
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
                color: status == NodeStatus.notStarted
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

class ExerciseListProBadge extends StatelessWidget {
  const ExerciseListProBadge({super.key});

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

class ExerciseMiniRatingStars extends StatelessWidget {
  final int? bestRating;
  final NodeStatus status;
  final MainAxisAlignment alignment;

  const ExerciseMiniRatingStars({
    super.key,
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
        case NodeStatus.mastered:
          label = 'Mastered';
        case NodeStatus.inProgress:
          label = 'In progress';
        case NodeStatus.completed:
          label = 'Completed';
        case NodeStatus.notStarted:
          label = 'Not started';
      }
      return Text(
        label,
        style: TextStyle(
          color: status == NodeStatus.inProgress
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

class FlightPathPainter extends CustomPainter {
  final List<ExerciseListItem> exercises;
  final List<UserExercise> userExercises;
  final double Function(int) nodeXCalculator;
  final double Function(int) nodeYCalculator;
  final int currentIndex;

  FlightPathPainter({
    required this.exercises,
    required this.userExercises,
    required this.nodeXCalculator,
    required this.nodeYCalculator,
    required this.currentIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMainPath(canvas, size);
    for (int i = 0; i < exercises.length; i++) {
      if (exercises[i].hasSubExercises) {
        _drawSubExerciseBranches(canvas, i, size.width);
      }
    }
    _drawClouds(canvas, size);
  }

  void _drawMainPath(Canvas canvas, Size size) {
    if (exercises.length < 2) return;

    for (int i = 0; i < exercises.length - 1; i++) {
      final startX = nodeXCalculator(i);
      final startY = nodeYCalculator(i);
      final endX = nodeXCalculator(i + 1);
      final endY = nodeYCalculator(i + 1);

      final item = exercises[i];
      final status = item.hasSubExercises
          ? aggregateStatus(
              userExercises, item.exerciseId, item.subExercises)
          : nodeStatus(findExerciseInList(userExercises, item.exerciseId));
      final isCompleted = status == NodeStatus.completed ||
          status == NodeStatus.mastered;

      final path = Path();
      path.moveTo(startX, startY);
      final midY = (startY + endY) / 2;
      path.cubicTo(startX, midY, endX, midY, endX, endY);

      if (isCompleted) {
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
        _drawDashedPath(canvas, path, _incompletePaint());
      }
    }
  }

  void _drawSubExerciseBranches(
      Canvas canvas, int parentIndex, double screenWidth) {
    final item = exercises[parentIndex];
    final cx = nodeXCalculator(parentIndex);
    final cy = nodeYCalculator(parentIndex);
    final subCount = item.subExercises.length;

    for (int si = 0; si < subCount; si++) {
      final sub = item.subExercises[si];
      final ue = findExerciseInList(userExercises, item.exerciseId, sub.subId);
      final subStatus = nodeStatus(ue);

      final subCx = _computeSubCx(cx, si, subCount, screenWidth);
      final subCy = cy + kSubExerciseOffsetY;

      final branchPath = Path();
      branchPath.moveTo(cx, cy + kNodeRadius);
      branchPath.quadraticBezierTo(
          cx, subCy - 10, subCx, subCy - kSubNodeRadius);

      if (subStatus == NodeStatus.completed ||
          subStatus == NodeStatus.mastered) {
        final completedPaint = Paint()
          ..color = AppColors.success.withValues(alpha: 0.6)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(branchPath, completedPaint);
      } else {
        _drawDashedPath(
            canvas, branchPath, _incompletePaint(width: 1.5));
      }
    }
  }

  void _drawClouds(Canvas canvas, Size size) {
    final cloudPaint = Paint()
      ..color = AppColors.onSurfaceVariantDark.withValues(alpha: 0.04)
      ..style = PaintingStyle.fill;

    final cloudPositions = [
      Offset(size.width * 0.7, size.height * 0.1),
      Offset(size.width * 0.15, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.5),
    ];

    for (final pos in cloudPositions) {
      canvas.drawCircle(pos, 20, cloudPaint);
      canvas.drawCircle(pos + const Offset(18, 5), 14, cloudPaint);
      canvas.drawCircle(pos + const Offset(-14, 6), 12, cloudPaint);
    }
  }

  Paint _incompletePaint({double width = 2.0}) => Paint()
    ..color = AppColors.onSurfaceVariantDark.withValues(alpha: 0.2)
    ..strokeWidth = width
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashLength = 6.0;
    const double gapLength = 4.0;

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final segmentLength = draw ? dashLength : gapLength;
        if (draw) {
          final extractPath = metric.extractPath(
            distance,
            math.min(distance + segmentLength, metric.length),
          );
          canvas.drawPath(extractPath, paint);
        }
        distance += segmentLength;
        draw = !draw;
      }
    }
  }

  @override
  bool shouldRepaint(FlightPathPainter oldDelegate) {
    return oldDelegate.userExercises != userExercises ||
        oldDelegate.currentIndex != currentIndex;
  }
}

// ---------------------------------------------------------------------------
// Loading / Error bodies
// ---------------------------------------------------------------------------

class ExerciseListLoadingBody extends StatelessWidget {
  const ExerciseListLoadingBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}

class ExerciseListErrorBody extends ConsumerWidget {
  const ExerciseListErrorBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Could not load exercises',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => ref.invalidate(userExercisesProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// Flashcard screen — swipe-through revision mode with 3D flip animation.
// Cards can be swiped right ("got it") or left ("needs review").
import 'dart:math';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/flashcard.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/spaced_repetition_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class FlashcardScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const FlashcardScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen> {
  List<Flashcard> _cards = [];
  List<Flashcard> _currentDeck = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _isAnimating = false;
  bool _showSummary = false;
  bool _isRetryMode = false;

  final List<Flashcard> _gotIt = [];
  final List<Flashcard> _needsReview = [];

  double _dragOffset = 0;
  _SwipeDirection? _swipeHint;
  SpacedRepResult? _spacedRepResult;

  @override
  void initState() {
    super.initState();
  }

  void _shuffle() {
    setState(() {
      _currentDeck.shuffle(Random());
      _currentIndex = 0;
      _isFlipped = false;
      _gotIt.clear();
      _needsReview.clear();
      _showSummary = false;
      _isRetryMode = false;
    });
  }

  void _markCard(_SwipeDirection direction) {
    if (_isAnimating || _showSummary) return;
    final card = _currentDeck[_currentIndex];

    setState(() {
      if (direction == _SwipeDirection.right) {
        _gotIt.add(card);
      } else {
        _needsReview.add(card);
      }

      if (_currentIndex < _currentDeck.length - 1) {
        _currentIndex++;
        _isFlipped = false;
      } else {
        _showSummary = true;
        if (!_isRetryMode) _markFlashcardsCompleted();
      }
      _dragOffset = 0;
      _swipeHint = null;
    });
  }

  Future<void> _markFlashcardsCompleted() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final exercises = ref.read(userExercisesProvider).valueOrNull ?? [];
    final existing = exercises
        .where((ue) =>
            ue.exerciseId == exerciseId && ue.subExercise == subExerciseId)
        .firstOrNull;

    // Calculate spaced repetition result.
    final baseUe = existing ??
        UserExercise(
          id: '',
          exerciseId: exerciseId,
          subExercise: subExerciseId,
          exerciseNumber: 0,
          status: ExerciseStatus.inProgress,
          timesAttempted: 0,
          ratingHistory: [],
        );

    final result = SpacedRepetitionService.calculateSessionResult(
      userExercise: baseUe,
      gotIt: _gotIt,
      needsReview: _needsReview,
    );

    setState(() => _spacedRepResult = result);

    final firestore = ref.read(firestoreServiceProvider);
    await firestore.upsertUserExercise(
      uid,
      UserExercise(
        id: existing?.id ?? '',
        exerciseId: exerciseId,
        subExercise: subExerciseId,
        exerciseNumber: existing?.exerciseNumber ?? 0,
        status: existing?.status ?? ExerciseStatus.inProgress,
        bestRating: existing?.bestRating,
        timesAttempted: existing?.timesAttempted ?? 0,
        ratingHistory: existing?.ratingHistory ?? [],
        lastAttempted: existing?.lastAttempted,
        videoWatched: existing?.videoWatched ?? false,
        briefViewed: existing?.briefViewed ?? false,
        flashcardsCompleted: true,
        weatherChecked: existing?.weatherChecked ?? false,
        quizPassed: existing?.quizPassed ?? false,
        quizAttempted: existing?.quizAttempted ?? false,
        visualisationViewed: existing?.visualisationViewed ?? false,
        spacedRepDue: result.nextReviewDate,
        quizMastery: result.updatedMastery,
      ),
    );
  }

  void _retryNeedsReview() {
    if (_needsReview.isEmpty) return;
    setState(() {
      _currentDeck = List.of(_needsReview);
      _currentDeck.shuffle(Random());
      _needsReview.clear();
      _gotIt.clear();
      _currentIndex = 0;
      _isFlipped = false;
      _showSummary = false;
      _isRetryMode = true;
    });
    FirebaseAnalytics.instance.logEvent(
      name: 'flashcards_retry',
      parameters: {
        'exercise_id': widget.compositeExerciseId,
        'retry_count': _currentDeck.length,
      },
    );
  }

  void _restartAll() {
    setState(() {
      _currentDeck = List.of(_cards);
      _currentIndex = 0;
      _isFlipped = false;
      _gotIt.clear();
      _needsReview.clear();
      _showSummary = false;
      _isRetryMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final exerciseName = exerciseLongName(widget.compositeExerciseId);
    final cardsAsync =
        ref.watch(flashcardsProvider(widget.compositeExerciseId));

    return cardsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: Text(exerciseName, style: const TextStyle(fontSize: 16)),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(
          title: Text(exerciseName, style: const TextStyle(fontSize: 16)),
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'Failed to load flashcards.',
            style: TextStyle(color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
      data: (data) {
        if (_cards.isEmpty && data.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _cards = data;
              _currentDeck = List.of(data);
            });
            FirebaseAnalytics.instance.logEvent(
              name: 'flashcard_viewed',
              parameters: {'exercise_id': widget.compositeExerciseId},
            );
            FirebaseAnalytics.instance.logEvent(
              name: 'flashcards_opened',
              parameters: {
                'exercise_id': widget.compositeExerciseId,
                'card_count': data.length,
              },
            );
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              _isRetryMode ? 'Retry — $exerciseName' : exerciseName,
              style: const TextStyle(fontSize: 16),
            ),
            elevation: 0,
            actions: [
              if (!_showSummary)
                IconButton(
                  onPressed: _shuffle,
                  icon: const Icon(Icons.shuffle_rounded),
                  tooltip: 'Shuffle cards',
                ),
              IconButton(
                onPressed: () {
                  final reviewed = _gotIt.length + _needsReview.length;
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$reviewed card${reviewed == 1 ? '' : 's'} reviewed',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Back to exercise',
              ),
            ],
          ),
          body: _cards.isEmpty
              ? Center(
                  child: Text(
                    'No flashcards available for this exercise.',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
                )
              : _showSummary
                  ? _buildSummary()
                  : _buildCardView(),
        );
      },
    );
  }

  // ── Card View ─────────────────────────────────────────────────────────────

  Widget _buildCardView() {
    final card = _currentDeck[_currentIndex];
    final total = _currentDeck.length;
    final progress = (_currentIndex + 1) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          // Progress indicator
          Row(
            children: [
              Text(
                'Card ${_currentIndex + 1} of $total',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_gotIt.isNotEmpty || _needsReview.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_rounded,
                        color: AppColors.success, size: 14),
                    const SizedBox(width: 3),
                    Text('${_gotIt.length}',
                        style: TextStyle(
                            color: AppColors.success, fontSize: 12)),
                    const SizedBox(width: 10),
                    Icon(Icons.refresh_rounded,
                        color: AppColors.warning, size: 14),
                    const SizedBox(width: 3),
                    Text('${_needsReview.length}',
                        style: TextStyle(
                            color: AppColors.warning, fontSize: 12)),
                  ],
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
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 24),

          // Swipe hint labels
          if (_swipeHint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _swipeHint == _SwipeDirection.right ? 'GOT IT' : 'NEEDS REVIEW',
                style: TextStyle(
                  color: _swipeHint == _SwipeDirection.right
                      ? AppColors.success
                      : AppColors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          // Flashcard
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isAnimating) {
                  setState(() => _isFlipped = !_isFlipped);
                }
              },
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragOffset += details.primaryDelta ?? 0;
                  if (_dragOffset > 40) {
                    _swipeHint = _SwipeDirection.right;
                  } else if (_dragOffset < -40) {
                    _swipeHint = _SwipeDirection.left;
                  } else {
                    _swipeHint = null;
                  }
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragOffset.abs() > 80) {
                  _markCard(_dragOffset > 0
                      ? _SwipeDirection.right
                      : _SwipeDirection.left);
                } else {
                  setState(() {
                    _dragOffset = 0;
                    _swipeHint = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                transform: Matrix4.translationValues(_dragOffset, 0, 0),
                child: _FlipCard(
                  front: card.front,
                  back: card.back,
                  isFlipped: _isFlipped,
                  onAnimationStart: () => _isAnimating = true,
                  onAnimationEnd: () => _isAnimating = false,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Tap to flip  \u2022  Swipe right = Got it  \u2022  Swipe left = Review',
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Manual buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _markCard(_SwipeDirection.left),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Review'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.warning,
                    side: BorderSide(
                        color: AppColors.warning.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _markCard(_SwipeDirection.right),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Got It'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Widget _buildSummary() {
    final total = _gotIt.length + _needsReview.length;
    final pct = total > 0 ? (_gotIt.length / total * 100).round() : 0;

    // Show "Next: Before You Fly" only for flight lessons — for ground
    // lessons, flashcards is the terminal prepare step.
    final (exId, subExId) = parseExerciseId(widget.compositeExerciseId);
    final lessonType = ref
        .read(exerciseContentProvider((exId, subExId)))
        .valueOrNull
        ?.lessonType;
    final showNextStep = lessonType == LessonType.flight;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      child: Column(
        children: [
          // Score circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
              border: Border.all(
                color: pct >= 80
                    ? AppColors.success
                    : pct >= 60
                        ? AppColors.warning
                        : AppColors.error,
                width: 3,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$pct%',
                    style: TextStyle(
                      color: pct >= 80
                          ? AppColors.success
                          : pct >= 60
                              ? AppColors.warning
                              : AppColors.error,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Got It',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Stats
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  _isRetryMode ? 'Retry Complete!' : 'Session Complete!',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _SummaryStat(
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                      label: 'Got It',
                      count: _gotIt.length,
                    ),
                    _SummaryStat(
                      icon: Icons.refresh_rounded,
                      color: AppColors.warning,
                      label: 'Review',
                      count: _needsReview.length,
                    ),
                    _SummaryStat(
                      icon: Icons.layers_rounded,
                      color: AppColors.primary,
                      label: 'Total',
                      count: total,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Spaced repetition next review info
          if (_spacedRepResult != null && !_isRetryMode) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_repeat_rounded,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _spacedRepResult!.daysUntilReview == 1
                          ? 'Next review in 1 day'
                          : 'Next review in ${_spacedRepResult!.daysUntilReview} days',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Needs review list
          if (_needsReview.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cards to Review',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._needsReview.map((card) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle,
                                color: AppColors.warning, size: 6),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                card.front,
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action buttons
          if (showNextStep) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.pushReplacement(
                    '/exercises/${widget.compositeExerciseId}/before-you-fly',
                  );
                },
                icon: const Icon(Icons.flight_takeoff_rounded),
                label: const Text('Next: Before You Fly'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          if (_needsReview.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: showNextStep
                  ? OutlinedButton.icon(
                      onPressed: _retryNeedsReview,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                          'Retry ${_needsReview.length} Card${_needsReview.length == 1 ? '' : 's'}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning,
                        side: BorderSide(
                            color: AppColors.warning.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _retryNeedsReview,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                          'Retry ${_needsReview.length} Card${_needsReview.length == 1 ? '' : 's'}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _restartAll,
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Start Over'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Exercise',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary stat widget
// ---------------------------------------------------------------------------

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _SummaryStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Swipe direction
// ---------------------------------------------------------------------------

enum _SwipeDirection { left, right }

// ---------------------------------------------------------------------------
// Flip card widget with 3D animation
// ---------------------------------------------------------------------------

class _FlipCard extends StatefulWidget {
  final String front;
  final String back;
  final bool isFlipped;
  final VoidCallback? onAnimationStart;
  final VoidCallback? onAnimationEnd;

  const _FlipCard({
    required this.front,
    required this.back,
    required this.isFlipped,
    this.onAnimationStart,
    this.onAnimationEnd,
  });

  @override
  State<_FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<_FlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addListener(() {
      if (_animation.value >= 0.5 && !_showBack && widget.isFlipped) {
        setState(() => _showBack = true);
      } else if (_animation.value < 0.5 && _showBack && !widget.isFlipped) {
        setState(() => _showBack = false);
      }
    });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        widget.onAnimationEnd?.call();
      }
    });
  }

  @override
  void didUpdateWidget(_FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      widget.onAnimationStart?.call();
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
    if (widget.front != oldWidget.front) {
      _controller.reset();
      _showBack = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final angle = _animation.value * pi;
        final isBackVisible = _animation.value >= 0.5;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(angle),
          child: isBackVisible
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _CardFace(
                    text: widget.back,
                    label: 'ANSWER',
                    labelColor: AppColors.success,
                    icon: Icons.lightbulb_rounded,
                  ),
                )
              : _CardFace(
                  text: widget.front,
                  label: 'QUESTION',
                  labelColor: AppColors.primary,
                  icon: Icons.help_outline_rounded,
                ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Card face widget
// ---------------------------------------------------------------------------

class _CardFace extends StatelessWidget {
  final String text;
  final String label;
  final Color labelColor;
  final IconData icon;

  const _CardFace({
    required this.text,
    required this.label,
    required this.labelColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: labelColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: labelColor, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

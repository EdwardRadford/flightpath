// SM-2 inspired spaced repetition service for flashcards.
// Uses the intervals from AppConstants.spacedRepIntervals: [1, 3, 7, 14] days.
// Tracks per-card mastery via quizMastery on UserExercise.
import 'dart:math' show min;

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/constants/flashcard_data.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

/// Result of a spaced repetition update after a flashcard session.
class SpacedRepResult {
  /// Updated quizMastery map (cardKey -> consecutive correct count).
  final Map<String, int> updatedMastery;

  /// Next review date based on the lowest mastery level in this session.
  final DateTime nextReviewDate;

  /// Number of days until the next review.
  final int daysUntilReview;

  const SpacedRepResult({
    required this.updatedMastery,
    required this.nextReviewDate,
    required this.daysUntilReview,
  });
}

/// Manages spaced repetition scheduling for flashcards.
///
/// Each flashcard is identified by a deterministic key derived from its front
/// text (since flashcards are statically defined and have no ID field).
/// Mastery is tracked in [UserExercise.quizMastery] as cardKey -> consecutive
/// correct count. The [spacedRepDue] field on UserExercise is set based on the
/// lowest mastery level encountered in the session.
class SpacedRepetitionService {
  static const List<int> _intervals = AppConstants.spacedRepIntervals;

  /// Generates a stable key for a flashcard based on its front text.
  ///
  /// Uses the first 40 characters of the front text with non-alphanumeric
  /// chars stripped, giving a human-readable and collision-resistant key.
  static String cardKey(Flashcard card) {
    final cleaned = card.front
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, min(40, card.front.replaceAll(RegExp(r'[^a-z0-9]'), '').length));
    return 'fc_$cleaned';
  }

  /// Calculates the next review interval in days for a given mastery level.
  ///
  /// Mastery level is clamped to the available intervals. For example:
  /// - mastery 0 -> 1 day
  /// - mastery 1 -> 3 days
  /// - mastery 2 -> 7 days
  /// - mastery 3+ -> 14 days
  static int intervalForMastery(int mastery) {
    final idx = mastery.clamp(0, _intervals.length - 1);
    return _intervals[idx];
  }

  /// Updates mastery for each card based on session results and calculates
  /// the next review date.
  ///
  /// - Cards in [gotIt] have their mastery incremented.
  /// - Cards in [needsReview] have their mastery reset to 0.
  /// - The next review date is based on the minimum mastery level across all
  ///   cards in this session (so weak cards pull the review date forward).
  static SpacedRepResult calculateSessionResult({
    required UserExercise userExercise,
    required List<Flashcard> gotIt,
    required List<Flashcard> needsReview,
  }) {
    final mastery = Map<String, int>.from(userExercise.quizMastery);

    // Update mastery for correct cards.
    for (final card in gotIt) {
      final key = cardKey(card);
      mastery[key] = (mastery[key] ?? 0) + 1;
    }

    // Reset mastery for incorrect cards.
    for (final card in needsReview) {
      final key = cardKey(card);
      mastery[key] = 0;
    }

    // Find the minimum mastery across all session cards to determine interval.
    int minMastery = _intervals.length; // start high
    for (final card in [...gotIt, ...needsReview]) {
      final key = cardKey(card);
      final m = mastery[key] ?? 0;
      if (m < minMastery) minMastery = m;
    }

    final days = intervalForMastery(minMastery);
    final nextReview = DateTime.now().add(Duration(days: days));

    return SpacedRepResult(
      updatedMastery: mastery,
      nextReviewDate: nextReview,
      daysUntilReview: days,
    );
  }

  /// Returns flashcards that are due for review.
  ///
  /// A card is due if:
  /// - Its mastery level is < 2 (not yet "mastered"), OR
  /// - The exercise's spacedRepDue is null or <= now (time-based review).
  ///
  /// If spacedRepDue is in the future and all cards have mastery >= 2,
  /// returns an empty list (nothing due yet).
  static List<Flashcard> getCardsForReview(
    UserExercise ue,
    List<Flashcard> allCards,
  ) {
    final now = DateTime.now();
    final isDue = ue.spacedRepDue == null || !ue.spacedRepDue!.isAfter(now);

    if (!isDue) {
      // Not time for review yet — only return cards with low mastery.
      return allCards.where((card) {
        final key = cardKey(card);
        final mastery = ue.quizMastery[key] ?? 0;
        return mastery < 2;
      }).toList();
    }

    // Time-based review is due — return all cards with mastery < 2,
    // plus all cards if the review date has passed (full review).
    final weakCards = <Flashcard>[];
    for (final card in allCards) {
      final key = cardKey(card);
      final mastery = ue.quizMastery[key] ?? 0;
      if (mastery < 2) {
        weakCards.add(card);
      }
    }

    // If all cards are mastered but review is due, return all cards
    // for a full refresh review.
    if (weakCards.isEmpty && isDue && ue.spacedRepDue != null) {
      return List.of(allCards);
    }

    return weakCards;
  }
}

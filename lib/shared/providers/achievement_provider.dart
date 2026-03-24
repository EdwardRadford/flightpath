// Achievement provider — tracks unlocked achievements and checks conditions.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/constants/achievements_data.dart';
import 'package:flight_path/shared/models/achievement.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

const _kUnlockedAchievementsKey = 'unlocked_achievements';
const _kLastActiveDateKey = 'achievement_last_active_date';
const _kCurrentStreakKey = 'achievement_current_streak';
const _kWeatherCheckCountKey = 'achievement_weather_checks';

/// Provides the current list of all achievements with unlock state.
final achievementProvider =
    StateNotifierProvider<AchievementNotifier, List<Achievement>>((ref) {
  return AchievementNotifier();
});

/// Notifier that manages achievement unlock state via SharedPreferences.
class AchievementNotifier extends StateNotifier<List<Achievement>> {
  AchievementNotifier() : super(allAchievements) {
    _loadUnlocked();
  }

  Map<String, DateTime> _unlockedMap = {};

  Future<void> _loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_kUnlockedAchievementsKey);
    if (jsonStr != null) {
      final Map<String, dynamic> decoded = json.decode(jsonStr);
      _unlockedMap = decoded.map(
        (key, value) => MapEntry(key, DateTime.parse(value as String)),
      );
    }
    _rebuildState();
  }

  Future<void> _saveUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = _unlockedMap.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );
    await prefs.setString(_kUnlockedAchievementsKey, json.encode(encoded));
  }

  void _rebuildState() {
    state = allAchievements.map((a) {
      final unlockedAt = _unlockedMap[a.id];
      if (unlockedAt != null) {
        return a.copyWith(unlocked: true, unlockedAt: unlockedAt);
      }
      return a;
    }).toList();
  }

  /// Checks all achievement conditions and returns IDs of newly unlocked ones.
  Future<List<String>> checkAchievements({
    required AppUser? user,
    required List<Lesson> lessons,
    required List<UserExercise> exercises,
  }) async {
    if (user == null) return [];

    final newlyUnlocked = <String>[];
    final completedLessons =
        lessons.where((l) => l.status == LessonStatus.completed).toList();

    // Update streak and pre-fetch async values before the sync loop.
    await _updateStreak();
    final streak = await _getCurrentStreak();
    final weatherChecks = await _getWeatherCheckCount();

    for (final achievement in allAchievements) {
      if (_unlockedMap.containsKey(achievement.id)) continue;

      final earned = _checkCondition(
        achievement.id,
        user: user,
        completedLessons: completedLessons,
        exercises: exercises,
        streak: streak,
        weatherCheckCount: weatherChecks,
      );

      if (earned) {
        _unlockedMap[achievement.id] = DateTime.now();
        newlyUnlocked.add(achievement.id);
      }
    }

    if (newlyUnlocked.isNotEmpty) {
      await _saveUnlocked();
      _rebuildState();
    }

    return newlyUnlocked;
  }

  bool _checkCondition(
    String id, {
    required AppUser user,
    required List<Lesson> completedLessons,
    required List<UserExercise> exercises,
    required int streak,
    required int weatherCheckCount,
  }) {
    switch (id) {
      // ── Milestones ────────────────────────────────────────────────────
      case 'first_lesson':
        return completedLessons.isNotEmpty;
      case 'five_lessons':
        return completedLessons.length >= 5;
      case 'ten_lessons':
        return completedLessons.length >= 10;
      case 'first_solo':
        return completedLessons.any((l) => l.exerciseId == 'ex_14');
      case 'all_exercises':
        final completedIds = exercises
            .where((e) => e.status == ExerciseStatus.complete)
            .map((e) {
          if (e.subExercise != null) return '${e.exerciseId}_${e.subExercise}';
          return e.exerciseId;
        }).toSet();
        // Need all 19 base exercises (using the 22 composite IDs)
        const required = {
          'ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05',
          'ex_06', 'ex_07', 'ex_08', 'ex_09',
          'ex_10_10a', 'ex_10_10b',
          'ex_11', 'ex_12', 'ex_13', 'ex_14', 'ex_15',
          'ex_16', 'ex_17',
          'ex_18_18a', 'ex_18_18b', 'ex_18_18c',
          'ex_19',
        };
        return required.every(completedIds.contains);
      case 'ten_hours':
        return user.hoursFlown >= 10;
      case 'fifty_hours':
        return user.hoursFlown >= 50;

      // ── Mastery ───────────────────────────────────────────────────────
      case 'first_five_star':
        return completedLessons.any((l) => l.studentRating == 5);
      case 'five_five_stars':
        final fiveStarExercises = <String>{};
        for (final l in completedLessons) {
          if (l.studentRating == 5) {
            final compositeId = l.subExercise != null
                ? '${l.exerciseId}_${l.subExercise}'
                : l.exerciseId;
            fiveStarExercises.add(compositeId);
          }
        }
        return fiveStarExercises.length >= 5;
      case 'quiz_ace':
        return completedLessons.any((l) => l.quizScore == 100);
      case 'ten_quizzes':
        final passedQuizzes =
            completedLessons.where((l) => l.quizPassed == true).length;
        return passedQuizzes >= 10;
      case 'all_flashcards':
        // This would need flashcard tracking — for now check via SharedPrefs
        return _checkFlashcardCompletion();

      // ── Consistency ───────────────────────────────────────────────────
      case 'three_day_streak':
        return streak >= 3;
      case 'seven_day_streak':
        return streak >= 7;
      case 'thirty_day_streak':
        return streak >= 30;

      // ── Dedication ────────────────────────────────────────────────────
      case 'night_owl':
        return completedLessons.any((l) {
          final date = l.lessonDate ?? l.createdAt;
          return date.hour >= 20;
        });
      case 'early_bird':
        return completedLessons.any((l) {
          final date = l.lessonDate ?? l.createdAt;
          return date.hour < 8;
        });
      case 'weather_watcher':
        return weatherCheckCount >= 10;

      default:
        return false;
    }
  }

  bool _checkFlashcardCompletion() {
    // Placeholder — flashcard completion would be tracked elsewhere.
    // Returns false until flashcard tracking is wired in.
    return false;
  }

  // ── Streak tracking ──────────────────────────────────────────────────────

  Future<void> _updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDateStr = prefs.getString(_kLastActiveDateKey);
    final today = DateTime.now();
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    if (lastDateStr == todayStr) return; // Already recorded today

    final currentStreak = prefs.getInt(_kCurrentStreakKey) ?? 0;

    if (lastDateStr != null) {
      final lastDate = DateTime.parse(lastDateStr);
      final diff = DateTime(today.year, today.month, today.day)
          .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
          .inDays;

      if (diff == 1) {
        // Consecutive day
        await prefs.setInt(_kCurrentStreakKey, currentStreak + 1);
      } else if (diff > 1) {
        // Streak broken
        await prefs.setInt(_kCurrentStreakKey, 1);
      }
    } else {
      await prefs.setInt(_kCurrentStreakKey, 1);
    }

    await prefs.setString(_kLastActiveDateKey, todayStr);
  }

  Future<int> _getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kCurrentStreakKey) ?? 0;
  }

  // ── Weather check tracking ───────────────────────────────────────────────

  Future<int> _getWeatherCheckCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kWeatherCheckCountKey) ?? 0;
  }

  /// Call this from the weather briefing screen to increment the counter.
  static Future<void> incrementWeatherChecks() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_kWeatherCheckCountKey) ?? 0;
    await prefs.setInt(_kWeatherCheckCountKey, current + 1);
  }

  /// Returns the current weather check count.
  static Future<int> getWeatherChecksCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kWeatherCheckCountKey) ?? 0;
  }
}

/// Provider that exposes the count of unlocked achievements.
final unlockedAchievementCountProvider = Provider<int>((ref) {
  final achievements = ref.watch(achievementProvider);
  return achievements.where((a) => a.unlocked).length;
});

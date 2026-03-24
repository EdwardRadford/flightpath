// Achievement definitions — all available badges and their metadata.
import 'package:flutter/material.dart';
import 'package:flight_path/shared/models/achievement.dart';

/// Maps icon name strings to actual IconData for rendering.
IconData achievementIcon(String iconName) {
  switch (iconName) {
    case 'flight_takeoff':
      return Icons.flight_takeoff;
    case 'airplanemode_active':
      return Icons.airplanemode_active;
    case 'schedule':
      return Icons.schedule;
    case 'military_tech':
      return Icons.military_tech;
    case 'emoji_events':
      return Icons.emoji_events;
    case 'timer':
      return Icons.timer;
    case 'star':
      return Icons.star;
    case 'stars':
      return Icons.stars;
    case 'school':
      return Icons.school;
    case 'quiz':
      return Icons.quiz;
    case 'style':
      return Icons.style;
    case 'local_fire_department':
      return Icons.local_fire_department;
    case 'whatshot':
      return Icons.whatshot;
    case 'bolt':
      return Icons.bolt;
    case 'nightlight_round':
      return Icons.nightlight_round;
    case 'wb_sunny':
      return Icons.wb_sunny;
    case 'cloud':
      return Icons.cloud;
    default:
      return Icons.emoji_events;
  }
}

/// All available achievements in the app.
const List<Achievement> allAchievements = [
  // ── Milestones ──────────────────────────────────────────────────────────
  Achievement(
    id: 'first_lesson',
    title: 'First Steps',
    description: 'Complete your first lesson',
    iconName: 'flight_takeoff',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'five_lessons',
    title: 'Getting Airborne',
    description: 'Complete 5 lessons',
    iconName: 'airplanemode_active',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'ten_lessons',
    title: 'Building Hours',
    description: 'Complete 10 lessons',
    iconName: 'schedule',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'first_solo',
    title: 'Solo Pilot',
    description: 'Complete your first solo flight (Exercise 14)',
    iconName: 'military_tech',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'all_exercises',
    title: 'Syllabus Complete',
    description: 'Complete all 19 exercises',
    iconName: 'emoji_events',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'ten_hours',
    title: 'Double Digits',
    description: 'Log 10 hours of flight time',
    iconName: 'timer',
    category: AchievementCategory.milestone,
  ),
  Achievement(
    id: 'fifty_hours',
    title: 'Halfway There',
    description: 'Log 50 hours of flight time',
    iconName: 'timer',
    category: AchievementCategory.milestone,
  ),

  // ── Mastery ─────────────────────────────────────────────────────────────
  Achievement(
    id: 'first_five_star',
    title: 'Perfect Flight',
    description: 'Achieve a 5-star rating on any exercise',
    iconName: 'star',
    category: AchievementCategory.mastery,
  ),
  Achievement(
    id: 'five_five_stars',
    title: 'Gold Standard',
    description: 'Achieve 5-star ratings on 5 exercises',
    iconName: 'stars',
    category: AchievementCategory.mastery,
  ),
  Achievement(
    id: 'quiz_ace',
    title: 'Quiz Ace',
    description: 'Score 100% on any quiz',
    iconName: 'school',
    category: AchievementCategory.mastery,
  ),
  Achievement(
    id: 'ten_quizzes',
    title: 'Quiz Master',
    description: 'Pass 10 quizzes',
    iconName: 'quiz',
    category: AchievementCategory.mastery,
  ),
  Achievement(
    id: 'all_flashcards',
    title: 'Card Sharp',
    description: 'Complete all flashcards for any exercise',
    iconName: 'style',
    category: AchievementCategory.mastery,
  ),

  // ── Consistency ─────────────────────────────────────────────────────────
  Achievement(
    id: 'three_day_streak',
    title: 'On a Roll',
    description: 'Use the app 3 days in a row',
    iconName: 'local_fire_department',
    category: AchievementCategory.consistency,
  ),
  Achievement(
    id: 'seven_day_streak',
    title: 'Week Warrior',
    description: 'Use the app 7 days in a row',
    iconName: 'whatshot',
    category: AchievementCategory.consistency,
  ),
  Achievement(
    id: 'thirty_day_streak',
    title: 'Dedicated Student',
    description: 'Use the app 30 days in a row',
    iconName: 'bolt',
    category: AchievementCategory.consistency,
  ),

  // ── Dedication ──────────────────────────────────────────────────────────
  Achievement(
    id: 'night_owl',
    title: 'Night Owl',
    description: 'Complete a lesson after 8pm',
    iconName: 'nightlight_round',
    category: AchievementCategory.dedication,
  ),
  Achievement(
    id: 'early_bird',
    title: 'Early Bird',
    description: 'Complete a lesson before 8am',
    iconName: 'wb_sunny',
    category: AchievementCategory.dedication,
  ),
  Achievement(
    id: 'weather_watcher',
    title: 'Weather Watcher',
    description: 'Check 10 weather briefings',
    iconName: 'cloud',
    category: AchievementCategory.dedication,
  ),
];

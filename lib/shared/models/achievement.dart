// Achievement model — represents a gamification badge that can be unlocked.

/// Categories for grouping achievements.
enum AchievementCategory { milestone, consistency, mastery, dedication }

/// A single achievement/badge that can be unlocked by the user.
class Achievement {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final AchievementCategory category;
  final bool unlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.category,
    this.unlocked = false,
    this.unlockedAt,
  });

  /// Returns a copy with the given fields replaced.
  Achievement copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      iconName: iconName,
      category: category,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }
}

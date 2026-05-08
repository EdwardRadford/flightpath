// Achievements screen — shows all badges grouped by category.
// Unlocked achievements are colourful; locked ones are greyed out.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/achievements_data.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/achievement.dart';
import 'package:flight_path/shared/providers/achievement_provider.dart';

/// Colour and label for each achievement category.
extension _CategoryStyle on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.milestone:
        return 'Milestones';
      case AchievementCategory.mastery:
        return 'Mastery';
      case AchievementCategory.consistency:
        return 'Consistency';
      case AchievementCategory.dedication:
        return 'Dedication';
    }
  }

  Color get color {
    switch (this) {
      case AchievementCategory.milestone:
        return AppColors.primary;
      case AchievementCategory.mastery:
        return AppColors.success;
      case AchievementCategory.consistency:
        return AppColors.warning;
      case AchievementCategory.dedication:
        return AppColors.achievementDedication;
    }
  }

  IconData get categoryIcon {
    switch (this) {
      case AchievementCategory.milestone:
        return Icons.emoji_events_rounded;
      case AchievementCategory.mastery:
        return Icons.star_rounded;
      case AchievementCategory.consistency:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.dedication:
        return Icons.bolt_rounded;
    }
  }
}

/// Full-screen view of all achievements grouped by category.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achievements = ref.watch(achievementProvider);
    final unlockedCount = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;

    final categories = AchievementCategory.values;
    final grouped = {
      for (final cat in categories)
        cat: achievements.where((a) => a.category == cat).toList(),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Progress summary header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.military_tech_rounded,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unlockedCount of $total unlocked',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: total > 0 ? unlockedCount / total : 0,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Categories
          for (final cat in categories) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    Icon(cat.categoryIcon, color: cat.color, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: cat.color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${grouped[cat]!.where((a) => a.unlocked).length}/${grouped[cat]!.length}',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final achievement = grouped[cat]![index];
                    return _AchievementCard(
                      achievement: achievement,
                      categoryColor: cat.color,
                    );
                  },
                  childCount: grouped[cat]!.length,
                ),
              ),
            ),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

/// Individual achievement card — colourful when unlocked, greyed when locked.
class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final Color categoryColor;

  const _AchievementCard({
    required this.achievement,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;
    final iconColor = unlocked ? categoryColor : AppColors.onSurfaceVariant;
    final iconBg = unlocked
        ? categoryColor.withValues(alpha: 0.15)
        : AppColors.onSurfaceVariant.withValues(alpha: 0.08);
    final borderColor = unlocked
        ? categoryColor.withValues(alpha: 0.3)
        : AppColors.divider.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  achievementIcon(achievement.iconName),
                  color: iconColor,
                  size: 20,
                ),
              ),
              const Spacer(),
              if (unlocked)
                Icon(Icons.check_circle_rounded, color: categoryColor, size: 16)
              else
                Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  size: 16,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: unlocked ? AppColors.onSurface : AppColors.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(
              achievement.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.onSurfaceVariant.withValues(
                  alpha: unlocked ? 1.0 : 0.6,
                ),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
          if (unlocked && achievement.unlockedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              DateFormat('d MMM yyyy').format(achievement.unlockedAt!),
              style: TextStyle(
                color: categoryColor.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

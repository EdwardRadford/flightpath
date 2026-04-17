import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class LogbookFilterBar extends StatelessWidget {
  final String? selectedExerciseId;
  final DateTimeRange? dateRange;
  final bool hasFilters;
  final VoidCallback onExerciseTap;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearFilters;

  const LogbookFilterBar({
    super.key,
    required this.selectedExerciseId,
    required this.dateRange,
    required this.hasFilters,
    required this.onExerciseTap,
    required this.onDateRangeTap,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          // Exercise filter chip
          ActionChip(
            avatar: Icon(
              Icons.flight_rounded,
              size: 16,
              color: selectedExerciseId != null
                  ? Colors.white
                  : AppColors.onSurfaceVariant,
            ),
            label: Text(
              selectedExerciseId != null
                  ? exerciseDisplayName(selectedExerciseId!)
                  : 'Exercise',
              style: TextStyle(
                color: selectedExerciseId != null
                    ? Colors.white
                    : AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            backgroundColor: selectedExerciseId != null
                ? AppColors.primary
                : AppColors.surfaceVariant,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onPressed: onExerciseTap,
          ),
          // Date range chip
          ActionChip(
            avatar: Icon(
              Icons.date_range_rounded,
              size: 16,
              color: dateRange != null
                  ? Colors.white
                  : AppColors.onSurfaceVariant,
            ),
            label: Text(
              dateRange != null
                  ? '${dateFormat.format(dateRange!.start)} – ${dateFormat.format(dateRange!.end)}'
                  : 'Date Range',
              style: TextStyle(
                color: dateRange != null
                    ? Colors.white
                    : AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            backgroundColor: dateRange != null
                ? AppColors.primary
                : AppColors.surfaceVariant,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onPressed: onDateRangeTap,
          ),
          // Clear filters
          if (hasFilters)
            ActionChip(
              avatar: const Icon(
                Icons.clear_rounded,
                size: 16,
                color: AppColors.error,
              ),
              label: const Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
              backgroundColor: AppColors.error.withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: onClearFilters,
            ),
        ],
      ),
    );
  }
}

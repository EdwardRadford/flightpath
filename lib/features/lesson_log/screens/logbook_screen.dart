// Logbook screen — pilot logbook with running totals, reverse-chronological
// entries, calendar view, PDF export, and manual entry support.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _exerciseDisplayNameForLesson(Lesson lesson) {
  final key = compositeExerciseId(lesson.exerciseId, lesson.subExercise);
  return exerciseLongName(key);
}

String _formatMinutesAsHours(int minutes) {
  final hrs = minutes ~/ 60;
  final mins = minutes % 60;
  return '${hrs}h ${mins.toString().padLeft(2, '0')}m';
}

String _routeString(Lesson lesson) {
  final dep = lesson.departureAirfield ?? '';
  final arr = lesson.arrivalAirfield ?? '';
  if (dep.isEmpty && arr.isEmpty) return '';
  if (dep == arr || arr.isEmpty) return dep;
  if (dep.isEmpty) return arr;
  return '$dep \u2192 $arr';
}

// ---------------------------------------------------------------------------
// Sort mode
// ---------------------------------------------------------------------------

enum _SortMode { newestFirst, oldestFirst, exerciseNumber }


// ---------------------------------------------------------------------------
// Running totals model
// ---------------------------------------------------------------------------

class _LogbookTotals {
  final int totalMinutes;
  final int dualMinutes;
  final int picMinutes;
  final int totalLandings;
  final int entryCount;

  const _LogbookTotals({
    this.totalMinutes = 0,
    this.dualMinutes = 0,
    this.picMinutes = 0,
    this.totalLandings = 0,
    this.entryCount = 0,
  });

  factory _LogbookTotals.fromLessons(List<Lesson> lessons) {
    int total = 0, dual = 0, pic = 0, landings = 0;
    for (final l in lessons) {
      if (l.status == LessonStatus.cancelled) continue;
      total += l.flightTimeMinutes ?? l.lessonDuration ?? 0;
      dual += l.dualTimeMinutes ?? 0;
      pic += l.picTimeMinutes ?? 0;
      landings += l.landings ?? 0;
    }
    return _LogbookTotals(
      totalMinutes: total,
      dualMinutes: dual,
      picMinutes: pic,
      totalLandings: landings,
      entryCount: lessons.where((l) => l.status != LessonStatus.cancelled).length,
    );
  }
}

// ---------------------------------------------------------------------------
// LogbookScreen
// ---------------------------------------------------------------------------

class LogbookScreen extends ConsumerStatefulWidget {
  const LogbookScreen({super.key});

  @override
  ConsumerState<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends ConsumerState<LogbookScreen> {
  // Filter state
  String? _selectedExerciseId;
  DateTimeRange? _dateRange;
  _SortMode _sortMode = _SortMode.newestFirst;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _hasFilters =>
      _selectedExerciseId != null || _dateRange != null || _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDeleteLesson(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson'),
        content: const Text(
          'Are you sure you want to delete this lesson? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteLesson(String lessonId) async {
    try {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteLesson(lessonId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lesson deleted'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete lesson. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Applies filters and sort to the full lesson list.
  List<Lesson> _applyFiltersAndSort(List<Lesson> lessons) {
    var filtered = lessons
        .where((l) => l.status != LessonStatus.cancelled)
        .toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((l) {
        final compositeId = compositeExerciseId(l.exerciseId, l.subExercise);
        final exerciseName = exerciseLongName(compositeId).toLowerCase();
        final customName = (l.customExerciseName ?? '').toLowerCase();
        final date = l.lessonDate ?? l.createdAt;
        final dateStr = DateFormat('d MMM yyyy').format(date).toLowerCase();
        final reg = (l.aircraftRegistration ?? '').toLowerCase();
        final dep = (l.departureAirfield ?? '').toLowerCase();
        final arr = (l.arrivalAirfield ?? '').toLowerCase();
        final remarks = (l.remarks ?? '').toLowerCase();
        final instructorNotes = (l.instructorNotes ?? '').toLowerCase();
        final reflection = (l.personalReflection ?? '').toLowerCase();
        final instructor = (l.instructorName ?? '').toLowerCase();
        return exerciseName.contains(_searchQuery) ||
            customName.contains(_searchQuery) ||
            dateStr.contains(_searchQuery) ||
            reg.contains(_searchQuery) ||
            dep.contains(_searchQuery) ||
            arr.contains(_searchQuery) ||
            remarks.contains(_searchQuery) ||
            instructorNotes.contains(_searchQuery) ||
            reflection.contains(_searchQuery) ||
            instructor.contains(_searchQuery);
      }).toList();
    }

    // Filter by exercise
    if (_selectedExerciseId != null) {
      filtered = filtered.where((l) {
        final compositeId = compositeExerciseId(l.exerciseId, l.subExercise);
        return compositeId == _selectedExerciseId;
      }).toList();
    }

    // Filter by date range
    if (_dateRange != null) {
      final start = DateTime(
        _dateRange!.start.year,
        _dateRange!.start.month,
        _dateRange!.start.day,
      );
      final end = DateTime(
        _dateRange!.end.year,
        _dateRange!.end.month,
        _dateRange!.end.day,
        23, 59, 59,
      );
      filtered = filtered.where((l) {
        final date = l.lessonDate ?? l.createdAt;
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
    }

    // Sort
    switch (_sortMode) {
      case _SortMode.newestFirst:
        filtered.sort((a, b) {
          final dateA = a.lessonDate ?? a.createdAt;
          final dateB = b.lessonDate ?? b.createdAt;
          return dateB.compareTo(dateA);
        });
      case _SortMode.oldestFirst:
        filtered.sort((a, b) {
          final dateA = a.lessonDate ?? a.createdAt;
          final dateB = b.lessonDate ?? b.createdAt;
          return dateA.compareTo(dateB);
        });
      case _SortMode.exerciseNumber:
        filtered.sort((a, b) {
          final idA = compositeExerciseId(a.exerciseId, a.subExercise);
          final idB = compositeExerciseId(b.exerciseId, b.subExercise);
          return idA.compareTo(idB);
        });
    }

    return filtered;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _selectedExerciseId = null;
      _dateRange = null;
      _searchQuery = '';
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (result != null) {
      setState(() => _dateRange = result);
    }
  }

  void _showExerciseFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Filter by Exercise',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // "All exercises" option
              ListTile(
                leading: Icon(
                  _selectedExerciseId == null
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.primary,
                  size: 20,
                ),
                title: Text(
                  'All Exercises',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: _selectedExerciseId == null
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedExerciseId = null);
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 1),
              // Exercise list
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: AppConstants.allExerciseIds.length,
                  itemBuilder: (context, index) {
                    final id = AppConstants.allExerciseIds[index];
                    final name = exerciseLongName(id);
                    final isSelected = _selectedExerciseId == id;
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        setState(() => _selectedExerciseId = id);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sort By',
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SortOption(
                label: 'Newest First',
                icon: Icons.arrow_downward_rounded,
                isSelected: _sortMode == _SortMode.newestFirst,
                onTap: () {
                  setState(() => _sortMode = _SortMode.newestFirst);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Oldest First',
                icon: Icons.arrow_upward_rounded,
                isSelected: _sortMode == _SortMode.oldestFirst,
                onTap: () {
                  setState(() => _sortMode = _SortMode.oldestFirst);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Exercise Number',
                icon: Icons.format_list_numbered_rounded,
                isSelected: _sortMode == _SortMode.exerciseNumber,
                onTap: () {
                  setState(() => _sortMode = _SortMode.exerciseNumber);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return Scaffold(

      appBar: AppBar(
        title: const Text('Logbook'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortMenu,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryBright,
        foregroundColor: Colors.white,
        onPressed: () {
          FirebaseAnalytics.instance.logEvent(name: 'logbook_add_entry_tapped');
          context.push('/logbook/add');
        },
        child: const Icon(Icons.add),
      ),
      body: lessonsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, _) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Unable to load logbook. Please try again.',
              style: TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (lessons) {
          if (lessons.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.menu_book_rounded,
              title: 'Your aviation story starts here',
              subtitle:
                  'Log your first flight to begin tracking your hours, routes, and progress.',
              buttonText: 'Log Your First Flight',
              onButtonPressed: () => context.push('/logbook/add'),
            );
          }

          final filteredLessons = _applyFiltersAndSort(lessons);
          final totals = _LogbookTotals.fromLessons(filteredLessons);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search exercises, dates, notes…',
                      hintStyle: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.onSurfaceVariant,
                        size: 20,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.onSurfaceVariant,
                                size: 18,
                              ),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Filter bar
              SliverToBoxAdapter(
                child: _FilterBar(
                  selectedExerciseId: _selectedExerciseId,
                  dateRange: _dateRange,
                  hasFilters: _hasFilters,
                  onExerciseTap: _showExerciseFilter,
                  onDateRangeTap: _pickDateRange,
                  onClearFilters: _clearFilters,
                ),
              ),
              // Running totals (reflect filtered results)
              SliverToBoxAdapter(
                child: _TotalsCard(totals: totals),
              ),
              // Entry list
              if (filteredLessons.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No entries match "${_searchController.text.trim()}".'
                            : 'No entries match your filters.',
                        style: TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final lesson = filteredLessons[index];
                        return Dismissible(
                          key: ValueKey(lesson.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                          confirmDismiss: (_) => _confirmDeleteLesson(context),
                          onDismissed: (_) => _deleteLesson(lesson.id),
                          child: _LogbookEntryCard(lesson: lesson),
                        );
                      },
                      childCount: filteredLessons.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final String? selectedExerciseId;
  final DateTimeRange? dateRange;
  final bool hasFilters;
  final VoidCallback onExerciseTap;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearFilters;

  const _FilterBar({
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

// ---------------------------------------------------------------------------
// Sort option tile
// ---------------------------------------------------------------------------

class _SortOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: AppColors.onSurface,
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}


// ---------------------------------------------------------------------------
// Totals card
// ---------------------------------------------------------------------------

class _TotalsCard extends StatelessWidget {
  final _LogbookTotals totals;

  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _TotalItem(
              label: 'Total',
              value: _formatMinutesAsHours(totals.totalMinutes),
              icon: Icons.flight_rounded,
            ),
            _TotalItem(
              label: 'Dual',
              value: _formatMinutesAsHours(totals.dualMinutes),
              icon: Icons.people_outline,
            ),
            _TotalItem(
              label: 'PIC',
              value: _formatMinutesAsHours(totals.picMinutes),
              icon: Icons.person_outline,
            ),
            _TotalItem(
              label: 'Landings',
              value: '${totals.totalLandings}',
              icon: Icons.flight_land_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _TotalItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style:  TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style:  TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook entry card
// ---------------------------------------------------------------------------

class _LogbookEntryCard extends StatelessWidget {
  final Lesson lesson;

  const _LogbookEntryCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(date);
    final reg = lesson.aircraftRegistration ?? '';
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes ?? lesson.lessonDuration;
    final exerciseName = _exerciseDisplayNameForLesson(lesson);

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: date + day/night badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lesson.isDayFlight
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lesson.isDayFlight ? 'Day' : 'Night',
                    style: TextStyle(
                      color: lesson.isDayFlight
                          ? AppColors.warning
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Registration + route row
            Row(
              children: [
                if (reg.isNotEmpty) ...[
                  const Icon(Icons.airplanemode_active,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    reg,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                if (route.isNotEmpty) ...[
                   Icon(Icons.navigation_outlined,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      route,
                      style:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Flight time + landings + exercise
            Row(
              children: [
                if (flightTime != null) ...[
                   Icon(Icons.access_time_rounded,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _formatMinutesAsHours(flightTime),
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                if (lesson.landings != null) ...[
                   Icon(Icons.flight_land_outlined,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${lesson.landings} ldg',
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 6),

            // Exercise name
            Text(
              exerciseName,
              style:  TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _LogbookDetailSheet(lesson: lesson),
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook detail bottom sheet
// ---------------------------------------------------------------------------

class _LogbookDetailSheet extends StatefulWidget {
  final Lesson lesson;

  const _LogbookDetailSheet({required this.lesson});

  @override
  State<_LogbookDetailSheet> createState() => _LogbookDetailSheetState();
}

class _LogbookDetailSheetState extends State<_LogbookDetailSheet> {
  bool _showLessonDetail = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final date = lesson.lessonDate ?? lesson.createdAt;
    final exerciseName = _exerciseDisplayNameForLesson(lesson);
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes ?? lesson.lessonDuration;

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM yyyy').format(date),
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: lesson.isDayFlight
                        ? AppColors.warning.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    lesson.isDayFlight ? 'Day' : 'Night',
                    style: TextStyle(
                      color: lesson.isDayFlight
                          ? AppColors.warning
                          : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              exerciseName,
              style:  TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),

            // Logbook details grid
            _DetailRow(label: 'Aircraft', value: lesson.aircraftRegistration ?? '—'),
            _DetailRow(
              label: 'Aircraft Type',
              value: _aircraftTypeLabel(lesson.aircraftType),
            ),
            if (route.isNotEmpty) _DetailRow(label: 'Route', value: route),
            if (flightTime != null)
              _DetailRow(
                  label: 'Flight Time',
                  value: _formatMinutesAsHours(flightTime)),
            if (lesson.dualTimeMinutes != null)
              _DetailRow(
                  label: 'Dual Time',
                  value: _formatMinutesAsHours(lesson.dualTimeMinutes!)),
            if (lesson.picTimeMinutes != null)
              _DetailRow(
                  label: 'PIC Time',
                  value: _formatMinutesAsHours(lesson.picTimeMinutes!)),
            if (lesson.landings != null)
              _DetailRow(label: 'Landings', value: '${lesson.landings}'),
            if (lesson.instructorName != null &&
                lesson.instructorName!.isNotEmpty)
              _DetailRow(label: 'Instructor', value: lesson.instructorName!),
            if (lesson.remarks != null && lesson.remarks!.isNotEmpty) ...[
              const SizedBox(height: 12),
               Text(
                'Remarks',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                lesson.remarks!,
                style:  TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            // Expandable lesson detail (ratings, quiz, AI debrief)
            if (_hasLessonDetail(lesson)) ...[
              const SizedBox(height: 20),
              Divider(color: AppColors.divider),
              GestureDetector(
                onTap: () => setState(() => _showLessonDetail = !_showLessonDetail),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                       Expanded(
                        child: Text(
                          'Lesson Details',
                          style: TextStyle(
                            color: AppColors.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        _showLessonDetail
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showLessonDetail) _LessonDetailSection(lesson: lesson),
            ],

            // View full detail button
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/lesson-detail', extra: lesson);
                },
                icon: const Icon(Icons.open_in_full_rounded, size: 16),
                label: const Text('View Full Detail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  bool _hasLessonDetail(Lesson lesson) {
    return lesson.studentRating != null ||
        lesson.instructorRating != null ||
        lesson.quizScore != null ||
        lesson.aiDebriefWell != null ||
        lesson.instructorNotes != null ||
        lesson.personalReflection != null;
  }

  String _aircraftTypeLabel(String? type) {
    switch (type) {
      case 'cessna_152':
        return 'Cessna 152';
      case 'cessna_172':
        return 'Cessna 172';
      case 'pa28':
        return 'Piper PA-28';
      case 'da40':
        return 'Diamond DA40';
      default:
        return type ?? '—';
    }
  }
}

// ---------------------------------------------------------------------------
// Detail row
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style:  TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable lesson detail section
// ---------------------------------------------------------------------------

class _LessonDetailSection extends StatelessWidget {
  final Lesson lesson;

  const _LessonDetailSection({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ratings row
        if (lesson.studentRating != null || lesson.instructorRating != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                if (lesson.studentRating != null)
                  _MiniStat(
                    icon: Icons.star_rounded,
                    label: 'Self',
                    value: '${lesson.studentRating}/5',
                  ),
                if (lesson.studentRating != null) const SizedBox(width: 12),
                if (lesson.instructorRating != null)
                  _MiniStat(
                    icon: Icons.person_rounded,
                    label: 'Instructor',
                    value: '${lesson.instructorRating}/5',
                  ),
                if (lesson.quizScore != null) ...[
                  const SizedBox(width: 12),
                  _MiniStat(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz',
                    value: '${lesson.quizScore}%',
                  ),
                ],
              ],
            ),
          ),

        // Instructor notes
        if (lesson.instructorNotes != null &&
            lesson.instructorNotes!.isNotEmpty) ...[
           Text(
            "Instructor's Comments",
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.instructorNotes!,
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Personal reflection
        if (lesson.personalReflection != null &&
            lesson.personalReflection!.isNotEmpty) ...[
           Text(
            'Personal Reflection',
            style: TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            lesson.personalReflection!,
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],

        // AI Debrief
        if (lesson.aiDebriefWell != null ||
            lesson.aiDebriefImprove != null ||
            lesson.aiDebriefFocus != null) ...[
           Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 14),
              SizedBox(width: 6),
              Text(
                'AI Debrief',
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (lesson.aiDebriefWell != null)
            _AiField(
              label: 'What Went Well',
              content: lesson.aiDebriefWell!,
              color: AppColors.success,
            ),
          if (lesson.aiDebriefImprove != null)
            _AiField(
              label: 'What to Improve',
              content: lesson.aiDebriefImprove!,
              color: AppColors.warning,
            ),
          if (lesson.aiDebriefFocus != null)
            _AiField(
              label: 'Focus Next Lesson',
              content: lesson.aiDebriefFocus!,
              color: AppColors.primary,
            ),
        ],
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style:  TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _AiField extends StatelessWidget {
  final String label;
  final String content;
  final Color color;

  const _AiField({
    required this.label,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style:  TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

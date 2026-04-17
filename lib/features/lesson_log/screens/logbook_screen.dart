// Logbook screen — pilot logbook with running totals, reverse-chronological
// entries, calendar view, PDF export, and manual entry support.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/features/lesson_log/widgets/logbook_entry_card.dart';
import 'package:flight_path/features/lesson_log/widgets/logbook_filter_bar.dart';
import 'package:flight_path/features/lesson_log/widgets/logbook_sort_option.dart';
import 'package:flight_path/features/lesson_log/widgets/logbook_totals_card.dart';

// ---------------------------------------------------------------------------
// Sort mode
// ---------------------------------------------------------------------------

enum _SortMode { newestFirst, oldestFirst, exerciseNumber }

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
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.deleteLesson(uid, lessonId);
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
        final customName = l.customExerciseName.toLowerCase();
        final date = l.lessonDate ?? l.createdAt;
        final dateStr = DateFormat('d MMM yyyy').format(date).toLowerCase();
        final reg = l.aircraftRegistration.toLowerCase();
        final dep = l.departureAirfield.toLowerCase();
        final arr = l.arrivalAirfield.toLowerCase();
        final remarks = l.remarks.toLowerCase();
        final instructorNotes = l.instructorNotes.toLowerCase();
        final reflection = l.personalReflection.toLowerCase();
        final instructor = l.instructorName.toLowerCase();
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
              LogbookSortOption(
                label: 'Newest First',
                icon: Icons.arrow_downward_rounded,
                isSelected: _sortMode == _SortMode.newestFirst,
                onTap: () {
                  setState(() => _sortMode = _SortMode.newestFirst);
                  Navigator.pop(context);
                },
              ),
              LogbookSortOption(
                label: 'Oldest First',
                icon: Icons.arrow_upward_rounded,
                isSelected: _sortMode == _SortMode.oldestFirst,
                onTap: () {
                  setState(() => _sortMode = _SortMode.oldestFirst);
                  Navigator.pop(context);
                },
              ),
              LogbookSortOption(
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
        error: (_, __) => const Center(
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
          final totals = LogbookTotals.fromLessons(filteredLessons);

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
                child: LogbookFilterBar(
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
                child: LogbookTotalsCard(totals: totals),
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
                          child: LogbookEntryCard(lesson: lesson),
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

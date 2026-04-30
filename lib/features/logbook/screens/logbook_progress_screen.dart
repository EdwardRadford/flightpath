// Combined Logbook & Progress screen — tabbed view with Entries, Hours, and
// Syllabus tabs, plus sort/export/achievements/weak-areas/share actions.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/logbook/providers/logbook_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/services/data_export_service.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/services/pdf_export_service.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import 'package:flight_path/shared/widgets/premium_paywall.dart';

// ---------------------------------------------------------------------------
// Helpers (from original logbook_screen.dart)
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
  final dep = lesson.departureAirfield;
  final arr = lesson.arrivalAirfield;
  if (dep.isEmpty && arr.isEmpty) return '';
  if (dep == arr || arr.isEmpty) return dep;
  if (dep.isEmpty) return arr;
  return '$dep \u2192 $arr';
}

// ---------------------------------------------------------------------------
// Syllabus phases (from original progress_screen.dart)
// ---------------------------------------------------------------------------

const _phases = [
  _Phase(
    name: 'Phase 1 \u2013 Basics',
    subtitle: 'Exercises 1\u20139',
    ids: [
      'ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05', 'ex_06', 'ex_07',
      'ex_08', 'ex_09',
    ],
  ),
  _Phase(
    name: 'Phase 2 \u2013 Manoeuvres',
    subtitle: 'Exercises 10\u201313',
    ids: ['ex_10_10a', 'ex_10_10b', 'ex_11', 'ex_12', 'ex_13'],
  ),
  _Phase(
    name: 'Phase 3 \u2013 First Solo',
    subtitle: 'Exercise 14',
    ids: ['ex_14'],
  ),
  _Phase(
    name: 'Phase 4 \u2013 Advanced',
    subtitle: 'Exercises 15\u201319',
    ids: [
      'ex_15', 'ex_16', 'ex_17', 'ex_18_18a', 'ex_18_18b', 'ex_18_18c',
      'ex_19',
    ],
  ),
];

class _Phase {
  final String name;
  final String subtitle;
  final List<String> ids;
  const _Phase({
    required this.name,
    required this.subtitle,
    required this.ids,
  });
}

// ---------------------------------------------------------------------------
// LogbookProgressScreen
// ---------------------------------------------------------------------------

class LogbookProgressScreen extends ConsumerStatefulWidget {
  /// Optional composite exercise id to pre-filter the entries tab to.
  /// When set, the screen opens on the Entries tab with only matching lessons
  /// shown — used by the prepare hub "Review Relevant Lessons" card.
  final String? initialExerciseId;

  const LogbookProgressScreen({super.key, this.initialExerciseId});

  @override
  ConsumerState<LogbookProgressScreen> createState() =>
      _LogbookProgressScreenState();
}

class _LogbookProgressScreenState extends ConsumerState<LogbookProgressScreen>
    with SingleTickerProviderStateMixin {
  static const _tabNames = ['entries', 'hours', 'syllabus'];
  late final TabController _tabController;

  // --- Entries tab state ---
  String? _selectedExerciseId;
  DateTimeRange? _dateRange;
  LogbookSort _sortMode = LogbookSort.newestFirst;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  bool get _hasFilters =>
      _selectedExerciseId != null ||
      _dateRange != null ||
      _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Pre-apply exercise filter when the screen is opened with one.
    if (widget.initialExerciseId != null) {
      _selectedExerciseId = widget.initialExerciseId;
    }
    FirebaseAnalytics.instance.logEvent(
      name: 'logbook_progress_viewed',
      parameters: {'tab_name': 'entries'},
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        FirebaseAnalytics.instance.logEvent(
          name: 'logbook_progress_viewed',
          parameters: {'tab_name': _tabNames[_tabController.index]},
        );
      }
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Delete lesson ---

  Future<bool> _confirmDeleteLesson(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Lesson'),
        content: Text(
          'Are you sure you want to delete this lesson? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteLesson(String lessonId) async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
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

  // --- Filtering / sorting ---

  List<Lesson> _applyFiltersAndSort(List<Lesson> lessons) {
    var filtered =
        lessons.where((l) => l.status != LessonStatus.cancelled).toList();

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

    if (_selectedExerciseId != null) {
      filtered = filtered.where((l) {
        final compositeId = compositeExerciseId(l.exerciseId, l.subExercise);
        return compositeId == _selectedExerciseId;
      }).toList();
    }

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
        23,
        59,
        59,
      );
      filtered = filtered.where((l) {
        final date = l.lessonDate ?? l.createdAt;
        return !date.isBefore(start) && !date.isAfter(end);
      }).toList();
    }

    switch (_sortMode) {
      case LogbookSort.newestFirst:
        filtered.sort((a, b) {
          final dateA = a.lessonDate ?? a.createdAt;
          final dateB = b.lessonDate ?? b.createdAt;
          return dateB.compareTo(dateA);
        });
      case LogbookSort.oldestFirst:
        filtered.sort((a, b) {
          final dateA = a.lessonDate ?? a.createdAt;
          final dateB = b.lessonDate ?? b.createdAt;
          return dateA.compareTo(dateB);
        });
      case LogbookSort.byExercise:
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
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
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
              _SortOption(
                label: 'Newest First',
                icon: Icons.arrow_downward_rounded,
                isSelected: _sortMode == LogbookSort.newestFirst,
                onTap: () {
                  setState(() => _sortMode = LogbookSort.newestFirst);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Oldest First',
                icon: Icons.arrow_upward_rounded,
                isSelected: _sortMode == LogbookSort.oldestFirst,
                onTap: () {
                  setState(() => _sortMode = LogbookSort.oldestFirst);
                  Navigator.pop(context);
                },
              ),
              _SortOption(
                label: 'Exercise Number',
                icon: Icons.format_list_numbered_rounded,
                isSelected: _sortMode == LogbookSort.byExercise,
                onTap: () {
                  setState(() => _sortMode = LogbookSort.byExercise);
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

  // --- Export ---

  Future<void> _exportPdf(List<Lesson> lessons) async {
    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null) return;
    try {
      await PdfExportService.exportLogbook(lessons: lessons, user: appUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to generate PDF. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    try {
      await DataExportService().exportAndShare(uid);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to export data. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // --- Build ---

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Logbook'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.sort_rounded),
            tooltip: 'Sort',
            onPressed: _showSortMenu,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              final lessons = lessonsAsync.valueOrNull ?? [];
              if (value == 'pdf') _exportPdf(lessons);
              if (value == 'export') _exportData();
              if (value == 'achievements') context.push('/achievements');
              if (value == 'weak-areas') context.push('/weak-areas');
              if (value == 'share') context.push('/share-progress');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Export PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Export Data (JSON)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'achievements',
                child: Row(
                  children: [
                    Icon(Icons.military_tech_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Achievements'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'weak-areas',
                child: Row(
                  children: [
                    Icon(Icons.track_changes_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Weak Areas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Share with Instructor'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
          tabs: const [
            Tab(text: 'Entries'),
            Tab(text: 'Hours'),
            Tab(text: 'Syllabus'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryBright,
        foregroundColor: Colors.white,
        onPressed: () {
          FirebaseAnalytics.instance
              .logEvent(name: 'logbook_add_entry_tapped');
          context.push('/logbook/add');
        },
        child: Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _EntriesTab(
            lessonsAsync: lessonsAsync,
            searchController: _searchController,
            searchQuery: _searchQuery,
            selectedExerciseId: _selectedExerciseId,
            dateRange: _dateRange,
            hasFilters: _hasFilters,
            applyFiltersAndSort: _applyFiltersAndSort,
            onExerciseTap: _showExerciseFilter,
            onDateRangeTap: _pickDateRange,
            onClearFilters: _clearFilters,
            confirmDeleteLesson: _confirmDeleteLesson,
            deleteLesson: _deleteLesson,
            onRetry: () => ref.invalidate(allLessonsProvider),
          ),
          const _HoursTab(),
          const _SyllabusTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Entries (from original LogbookScreen body)
// ---------------------------------------------------------------------------

class _EntriesTab extends StatelessWidget {
  final AsyncValue<List<Lesson>> lessonsAsync;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedExerciseId;
  final DateTimeRange? dateRange;
  final bool hasFilters;
  final List<Lesson> Function(List<Lesson>) applyFiltersAndSort;
  final VoidCallback onExerciseTap;
  final VoidCallback onDateRangeTap;
  final VoidCallback onClearFilters;
  final Future<bool> Function(BuildContext) confirmDeleteLesson;
  final Future<void> Function(String) deleteLesson;
  final VoidCallback onRetry;

  const _EntriesTab({
    required this.lessonsAsync,
    required this.searchController,
    required this.searchQuery,
    required this.selectedExerciseId,
    required this.dateRange,
    required this.hasFilters,
    required this.applyFiltersAndSort,
    required this.onExerciseTap,
    required this.onDateRangeTap,
    required this.onClearFilters,
    required this.confirmDeleteLesson,
    required this.deleteLesson,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return lessonsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary)),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  color: AppColors.error, size: 40),
              const SizedBox(height: 16),
              Text(
                'Unable to load logbook',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString().contains('FAILED_PRECONDITION')
                    ? 'A database index is being built. Please try again shortly.'
                    : error.toString().contains('PERMISSION_DENIED')
                        ? 'Permission denied. Please sign out and sign back in.'
                        : 'Please check your connection and try again.',
                style: TextStyle(
                    color: AppColors.onSurfaceVariant, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: Icon(Icons.refresh_rounded, size: 18),
                label: Text('Retry'),
              ),
            ],
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

        final filteredLessons = applyFiltersAndSort(lessons);
        final totals = LogbookTotals.fromLessons(filteredLessons);

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Screen subtitle
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Add and review your flight entries',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            // Search bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: searchController,
                  style:
                      TextStyle(color: AppColors.onSurface, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search exercises, dates, notes\u2026',
                    hintStyle: TextStyle(
                        color: AppColors.onSurfaceVariant, fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.onSurfaceVariant, size: 20),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                color: AppColors.onSurfaceVariant,
                                size: 18),
                            onPressed: () => searchController.clear(),
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
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
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            // Filter bar
            SliverToBoxAdapter(
              child: _FilterBar(
                selectedExerciseId: selectedExerciseId,
                dateRange: dateRange,
                hasFilters: hasFilters,
                onExerciseTap: onExerciseTap,
                onDateRangeTap: onDateRangeTap,
                onClearFilters: onClearFilters,
              ),
            ),
            // Running totals
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
                      searchQuery.isNotEmpty
                          ? 'No entries match "${searchController.text.trim()}".'
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
                          child: Icon(Icons.delete_rounded,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) =>
                            confirmDeleteLesson(context),
                        onDismissed: (_) => deleteLesson(lesson.id),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Hours (from original progress_screen.dart _HoursTab)
// ---------------------------------------------------------------------------

enum _HoursFilter { all, thisMonth, thisYear }

class _HoursTab extends ConsumerStatefulWidget {
  const _HoursTab();

  @override
  ConsumerState<_HoursTab> createState() => _HoursTabState();
}

class _HoursTabState extends ConsumerState<_HoursTab> {
  _HoursFilter _filter = _HoursFilter.all;

  static const double _pplGoal = 45.0;
  static const String _firstSoloId = 'ex_14';

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'logbook_viewed');
  }

  List<Lesson> _filtered(List<Lesson> lessons) {
    final now = DateTime.now();
    switch (_filter) {
      case _HoursFilter.all:
        return lessons;
      case _HoursFilter.thisMonth:
        return lessons.where((l) {
          final d = l.lessonDate ?? l.createdAt;
          return d.year == now.year && d.month == now.month;
        }).toList();
      case _HoursFilter.thisYear:
        return lessons.where((l) {
          final d = l.lessonDate ?? l.createdAt;
          return d.year == now.year;
        }).toList();
    }
  }

  double _totalHours(List<Lesson> lessons) {
    double total = 0;
    for (final l in lessons) {
      final isCountable = l.status == LessonStatus.completed ||
          l.status == LessonStatus.manualEntry;
      if (isCountable) {
        final minutes =
            l.flightTimeMinutes > 0 ? l.flightTimeMinutes : l.lessonDuration;
        if (minutes > 0) {
          total += minutes / 60.0;
        }
      }
    }
    return total;
  }

  bool _isSolo(Lesson l) => l.exerciseId == _firstSoloId;

  String _hhMm(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lessonsAsync = ref.watch(allLessonsProvider);

    return lessonsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Unable to load data. Please try again.',
                style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(allLessonsProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (allLessons) {
        final allCompleted = allLessons
            .where((l) =>
                l.status == LessonStatus.completed ||
                l.status == LessonStatus.manualEntry)
            .toList();
        final totalHoursFlown = _totalHours(allCompleted);
        final progress = (totalHoursFlown / _pplGoal).clamp(0.0, 1.0);

        final soloLessons = allCompleted.where(_isSolo).toList();
        final dualLessons =
            allCompleted.where((l) => !_isSolo(l)).toList();
        final soloHours = _totalHours(soloLessons);
        final dualHours = _totalHours(dualLessons);

        final filtered = _filtered(allLessons);
        final filteredHours = _totalHours(filtered);
        final completedFiltered = filtered
            .where((l) =>
                l.status == LessonStatus.completed ||
                l.status == LessonStatus.manualEntry)
            .toList()
          ..sort((a, b) {
            final da = a.lessonDate ?? a.createdAt;
            final db = b.lessonDate ?? b.createdAt;
            return db.compareTo(da);
          });

        int totalMinutesFiltered = 0;
        for (final l in completedFiltered) {
          totalMinutesFiltered += l.lessonDuration;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular progress + hours
              Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 160,
                            height: 160,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 12,
                              backgroundColor: AppColors.surfaceVariant,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                totalHoursFlown.toStringAsFixed(1),
                                style: TextStyle(
                                  color: AppColors.onSurface,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'hrs flown',
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Goal: ${_pplGoal.toStringAsFixed(0)} hrs '
                      '(${(progress * 100).round()}% complete)',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${(_pplGoal - totalHoursFlown).clamp(0.0, _pplGoal).toStringAsFixed(1)} hrs to go',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dual / Solo split
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Dual',
                        hours: dualHours,
                        lessons: dualLessons.length,
                        icon: Icons.people_alt_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 52,
                        color: AppColors.divider),
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Solo',
                        hours: soloHours,
                        lessons: soloLessons.length,
                        icon: Icons.person_rounded,
                        color: AppColors.success,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 52,
                        color: AppColors.divider),
                    Expanded(
                      child: _HoursSplitCell(
                        label: 'Total',
                        hours: totalHoursFlown,
                        lessons: allCompleted.length,
                        icon: Icons.flight_rounded,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Filter chips
              Row(
                children: [
                  _HoursFilterChip(
                    label: 'All Time',
                    selected: _filter == _HoursFilter.all,
                    onTap: () =>
                        setState(() => _filter = _HoursFilter.all),
                  ),
                  const SizedBox(width: 8),
                  _HoursFilterChip(
                    label: 'This Month',
                    selected: _filter == _HoursFilter.thisMonth,
                    onTap: () => setState(
                        () => _filter = _HoursFilter.thisMonth),
                  ),
                  const SizedBox(width: 8),
                  _HoursFilterChip(
                    label: 'This Year',
                    selected: _filter == _HoursFilter.thisYear,
                    onTap: () => setState(
                        () => _filter = _HoursFilter.thisYear),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Logbook table header
              Row(
                children: [
                  Icon(Icons.menu_book_rounded,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Flight Logbook',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'CAA PPL(A) format \u00b7 ${completedFiltered.length} '
                'entr${completedFiltered.length == 1 ? 'y' : 'ies'}',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),

              if (completedFiltered.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 40),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.flight_takeoff_rounded,
                          color: AppColors.onSurfaceVariant, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'No entries for this period',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Complete a lesson and it will appear\nin your logbook.',
                        style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      _LogbookHeaderRow(),
                      Divider(height: 1, color: AppColors.divider),
                      ...completedFiltered
                          .asMap()
                          .entries
                          .map((entry) {
                        final index = entry.key;
                        final lesson = entry.value;
                        final isLast =
                            index == completedFiltered.length - 1;
                        return _LogbookDataRow(
                          lesson: lesson,
                          isSolo: _isSolo(lesson),
                          hhMm: _hhMm,
                          isLast: isLast,
                        );
                      }),
                      Divider(height: 1, color: AppColors.divider),
                      _LogbookTotalsRow(
                        totalLessons: completedFiltered.length,
                        totalMinutes: totalMinutesFiltered,
                        hhMm: _hhMm,
                        filteredHours: filteredHours,
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 12),

              if (completedFiltered.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.onSurfaceVariant, size: 13),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This digital logbook is for reference only. '
                          'Your official CAA logbook must be maintained separately and '
                          'signed by your instructor.',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Syllabus (from original progress_screen.dart _SyllabusTab)
// ---------------------------------------------------------------------------

class _SyllabusTab extends ConsumerWidget {
  const _SyllabusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercisesAsync = ref.watch(userExercisesProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;

    return exercisesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (_, __) => const Center(
        child: Text('Unable to load data. Please try again.',
            style: TextStyle(color: AppColors.error)),
      ),
      data: (userExercises) {
        final ueMap = <String, UserExercise>{};
        for (final ue in userExercises) {
          final key = ue.subExercise != null
              ? '${ue.exerciseId}_${ue.subExercise}'
              : ue.exerciseId;
          ueMap[key] = ue;
        }

        final totalComplete = AppConstants.allExerciseIds
            .where((id) => ueMap[id]?.status.isCompleted ?? false)
            .length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            // Overall summary
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CAA PPL(A) Syllabus',
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalComplete of ${AppConstants.allExerciseIds.length} exercises complete',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: totalComplete /
                          AppConstants.allExerciseIds.length,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            // Phase cards
            ..._phases.map((phase) {
              final phaseTotal = phase.ids.length;
              final phaseComplete = phase.ids
                  .where(
                      (id) => ueMap[id]?.status.isCompleted ?? false)
                  .length;
              final phaseProgress =
                  phaseTotal > 0 ? phaseComplete / phaseTotal : 0.0;

              Color phaseColor;
              if (phaseComplete == phaseTotal) {
                phaseColor = AppColors.success;
              } else if (phaseComplete > 0) {
                phaseColor = AppColors.warning;
              } else {
                phaseColor = AppColors.onSurfaceVariant;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  phase.name,
                                  style: TextStyle(
                                    color: AppColors.onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  phase.subtitle,
                                  style: TextStyle(
                                    color:
                                        AppColors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '$phaseComplete/$phaseTotal',
                            style: TextStyle(
                              color: phaseColor,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: phaseProgress,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              phaseColor),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(
                      height: 1,
                      color: AppColors.divider,
                      indent: 16,
                      endIndent: 16,
                    ),
                    ...phase.ids.map((id) {
                      final ue = ueMap[id];
                      final bestRating = ue?.bestRating;
                      final name = exerciseLongName(id);
                      final routeId = id;

                      Color itemColor;
                      if (bestRating == null) {
                        itemColor = AppColors.onSurfaceVariant;
                      } else if (bestRating <= 2) {
                        itemColor = AppColors.error;
                      } else if (bestRating <= 4) {
                        itemColor = AppColors.warning;
                      } else {
                        itemColor = AppColors.success;
                      }

                      final isLast = id == phase.ids.last;

                      return Column(
                        children: [
                          InkWell(
                            onTap: () {
                              final hasAccess = appUser?.canAccessExercise(routeId) ?? true;
                              if (!hasAccess) {
                                showPremiumPaywall(
                                  context,
                                  source: 'syllabus_tab',
                                  freeWindowStart: appUser?.freeWindowStart ?? 1,
                                  freeWindowEnd: appUser?.freeWindowEnd ?? 3,
                                );
                                return;
                              }
                              context.push('/exercises/$routeId');
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: itemColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      overflow:
                                          TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: bestRating == null
                                            ? AppColors
                                                .onSurfaceVariant
                                            : AppColors.onSurface,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (bestRating != null)
                                    Row(
                                      mainAxisSize:
                                          MainAxisSize.min,
                                      children: List.generate(
                                        5,
                                        (i) => Icon(
                                          (i + 1) <= bestRating
                                              ? Icons
                                                  .star_rounded
                                              : Icons
                                                  .star_outline_rounded,
                                          color: itemColor,
                                          size: 13,
                                        ),
                                      ),
                                    )
                                  else
                                    Icon(
                                      Icons
                                          .chevron_right_rounded,
                                      color: AppColors
                                          .onSurfaceVariant,
                                      size: 16,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (!isLast)
                            Divider(
                              height: 1,
                              color: AppColors.divider,
                              indent: 38,
                              endIndent: 16,
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: 4),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared widgets (from original logbook_screen.dart)
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
                borderRadius: BorderRadius.circular(8)),
            onPressed: onExerciseTap,
          ),
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
                  ? '${dateFormat.format(dateRange!.start)} \u2013 ${dateFormat.format(dateRange!.end)}'
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
                borderRadius: BorderRadius.circular(8)),
            onPressed: onDateRangeTap,
          ),
          if (hasFilters)
            ActionChip(
              avatar: Icon(Icons.clear_rounded,
                  size: 16, color: AppColors.error),
              label: Text(
                'Clear',
                style:
                    TextStyle(color: AppColors.error, fontSize: 13),
              ),
              backgroundColor:
                  AppColors.error.withValues(alpha: 0.1),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              onPressed: onClearFilters,
            ),
        ],
      ),
    );
  }
}

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
          ? Icon(Icons.check_rounded,
              color: AppColors.primary, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final LogbookTotals totals;

  const _TotalsCard({required this.totals});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3)),
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
          style: TextStyle(
            color: AppColors.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Logbook entry card (from original logbook_screen.dart)
// ---------------------------------------------------------------------------

class _LogbookEntryCard extends StatelessWidget {
  final Lesson lesson;

  const _LogbookEntryCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('EEE, d MMM yyyy').format(date);
    final reg = lesson.aircraftRegistration;
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes > 0
        ? lesson.flightTimeMinutes
        : (lesson.lessonDuration > 0 ? lesson.lessonDuration : null);
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
            // Date + status badge + day/night badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                _StatusBadge(status: lesson.status),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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

            // Registration + route
            Row(
              children: [
                if (reg.isNotEmpty) ...[
                  Icon(Icons.airplanemode_active,
                      color: AppColors.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    reg,
                    style: TextStyle(
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
                      style: TextStyle(
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

            // Flight time + landings
            Row(
              children: [
                if (flightTime != null) ...[
                  Icon(Icons.access_time_rounded,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _formatMinutesAsHours(flightTime),
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                if (lesson.landings > 0) ...[
                  Icon(Icons.flight_land_outlined,
                      color: AppColors.onSurfaceVariant, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '${lesson.landings} ldg',
                    style: TextStyle(
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
              style: TextStyle(
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
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final LessonStatus status;

  const _StatusBadge({required this.status});

  String get _label {
    switch (status) {
      case LessonStatus.completed:
        return 'Completed';
      case LessonStatus.scheduled:
        return 'Scheduled';
      case LessonStatus.cancelled:
        return 'Cancelled';
      case LessonStatus.manualEntry:
        return 'Manual';
      case LessonStatus.prepared:
        return 'Prepared';
    }
  }

  Color get _color {
    switch (status) {
      case LessonStatus.completed:
        return Colors.green.shade600;
      case LessonStatus.scheduled:
        return Colors.blue.shade600;
      case LessonStatus.cancelled:
        return Colors.grey.shade500;
      case LessonStatus.manualEntry:
        return Colors.green.shade600;
      case LessonStatus.prepared:
        return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
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
  State<_LogbookDetailSheet> createState() =>
      _LogbookDetailSheetState();
}

class _LogbookDetailSheetState extends State<_LogbookDetailSheet> {
  bool _showLessonDetail = false;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final date = lesson.lessonDate ?? lesson.createdAt;
    final exerciseName = _exerciseDisplayNameForLesson(lesson);
    final route = _routeString(lesson);
    final flightTime = lesson.flightTimeMinutes > 0
        ? lesson.flightTimeMinutes
        : (lesson.lessonDuration > 0 ? lesson.lessonDuration : null);

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
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
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
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),

            // Details
            _DetailRow(
                label: 'Aircraft',
                value: lesson.aircraftRegistration.isEmpty
                    ? '\u2014'
                    : lesson.aircraftRegistration),
            _DetailRow(
              label: 'Aircraft Type',
              value: _aircraftTypeLabel(lesson.aircraftType),
            ),
            if (route.isNotEmpty)
              _DetailRow(label: 'Route', value: route),
            if (flightTime != null)
              _DetailRow(
                label: 'Flight Time',
                value: _formatMinutesAsHours(flightTime),
              ),
            if (lesson.dualTimeMinutes > 0)
              _DetailRow(
                label: 'Dual Time',
                value:
                    _formatMinutesAsHours(lesson.dualTimeMinutes),
              ),
            if (lesson.picTimeMinutes > 0)
              _DetailRow(
                label: 'PIC Time',
                value:
                    _formatMinutesAsHours(lesson.picTimeMinutes),
              ),
            if (lesson.landings > 0)
              _DetailRow(
                  label: 'Landings',
                  value: '${lesson.landings}'),
            if (lesson.instructorName.isNotEmpty)
              _DetailRow(
                  label: 'Instructor',
                  value: lesson.instructorName),
            if (lesson.remarks.isNotEmpty) ...[
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
                lesson.remarks,
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            // Expandable lesson detail
            if (_hasLessonDetail(lesson)) ...[
              const SizedBox(height: 20),
              Divider(color: AppColors.divider),
              GestureDetector(
                onTap: () => setState(
                    () => _showLessonDetail = !_showLessonDetail),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.school_outlined,
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
              if (_showLessonDetail)
                _LessonDetailSection(lesson: lesson),
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
                icon:
                    Icon(Icons.open_in_full_rounded, size: 16),
                label: Text('View Full Detail'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(
                      color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
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
        lesson.quizScore > 0 ||
        lesson.aiDebriefWell.isNotEmpty ||
        lesson.instructorNotes.isNotEmpty ||
        lesson.personalReflection.isNotEmpty;
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
        return type?.isEmpty == true ? '\u2014' : (type ?? '\u2014');
    }
  }
}

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
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
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

class _LessonDetailSection extends StatelessWidget {
  final Lesson lesson;

  const _LessonDetailSection({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lesson.studentRating != null ||
            lesson.instructorRating != null)
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
                if (lesson.studentRating != null)
                  const SizedBox(width: 12),
                if (lesson.instructorRating != null)
                  _MiniStat(
                    icon: Icons.person_rounded,
                    label: 'Instructor',
                    value: '${lesson.instructorRating}/5',
                  ),
                if (lesson.quizScore > 0) ...[
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
        if (lesson.instructorNotes.isNotEmpty) ...[
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
            lesson.instructorNotes,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (lesson.personalReflection.isNotEmpty) ...[
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
            lesson.personalReflection,
            style: TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (lesson.aiDebriefWell.isNotEmpty ||
            lesson.aiDebriefImprove.isNotEmpty ||
            lesson.aiDebriefFocus.isNotEmpty) ...[
          Row(
            children: [
              Icon(Icons.auto_awesome,
                  color: AppColors.primary, size: 14),
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
          if (lesson.aiDebriefWell.isNotEmpty)
            _AiField(
              label: 'What Went Well',
              content: lesson.aiDebriefWell,
              color: AppColors.success,
            ),
          if (lesson.aiDebriefImprove.isNotEmpty)
            _AiField(
              label: 'What to Improve',
              content: lesson.aiDebriefImprove,
              color: AppColors.warning,
            ),
          if (lesson.aiDebriefFocus.isNotEmpty)
            _AiField(
              label: 'Focus Next Lesson',
              content: lesson.aiDebriefFocus,
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
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: AppColors.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          Text(
            label,
            style: TextStyle(
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
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: 0.35)),
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
            style: TextStyle(
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

// ---------------------------------------------------------------------------
// Hours tab widgets (from original progress_screen.dart)
// ---------------------------------------------------------------------------

class _HoursSplitCell extends StatelessWidget {
  final String label;
  final double hours;
  final int lessons;
  final IconData icon;
  final Color color;

  const _HoursSplitCell({
    required this.label,
    required this.hours,
    required this.lessons,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 6),
        Text(
          hours.toStringAsFixed(1),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$lessons lesson${lessons == 1 ? '' : 's'}',
          style: TextStyle(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _LogbookHeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(13)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text('Date', style: _headerStyle),
          ),
          Expanded(
            child: Text('Exercise',
                style: _headerStyle,
                overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: 42,
            child: Text('Time',
                style: _headerStyle,
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text('Type',
                style: _headerStyle,
                textAlign: TextAlign.center),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 36,
            child: Text('Rating',
                style: _headerStyle,
                textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  static final _headerStyle = TextStyle(
    color: AppColors.onSurfaceVariant,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
  );
}

class _LogbookDataRow extends StatelessWidget {
  final Lesson lesson;
  final bool isSolo;
  final String Function(int) hhMm;
  final bool isLast;

  const _LogbookDataRow({
    required this.lesson,
    required this.isSolo,
    required this.hhMm,
    required this.isLast,
  });

  Color _ratingColor(int? r) {
    if (r == null) return AppColors.onSurfaceVariant;
    if (r <= 2) return AppColors.error;
    if (r <= 4) return AppColors.warning;
    return AppColors.success;
  }

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('d MMM yy').format(date);

    final compositeKey = lesson.subExercise.isNotEmpty
        ? '${lesson.exerciseId}_${lesson.subExercise}'
        : lesson.exerciseId;
    final fullName = exerciseLongName(compositeKey);

    final shortName = fullName.contains('\u2013')
        ? fullName.substring(fullName.indexOf('\u2013') + 2)
        : fullName;

    final durationStr = hhMm(lesson.lessonDuration);

    final ratingColor = _ratingColor(lesson.studentRating);

    return Container(
      decoration: BoxDecoration(
        borderRadius: isLast
            ? const BorderRadius.vertical(
                bottom: Radius.circular(13))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    shortName,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    durationStr,
                    style: TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [
                        FontFeature.tabularFigures()
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSolo
                            ? AppColors.success
                                .withValues(alpha: 0.15)
                            : AppColors.primary
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        isSolo ? 'Solo' : 'Dual',
                        style: TextStyle(
                          color: isSolo
                              ? AppColors.success
                              : AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 36,
                  child: lesson.studentRating != null
                      ? Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(Icons.star_rounded,
                                color: ratingColor, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              '${lesson.studentRating}',
                              style: TextStyle(
                                color: ratingColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          '\u2014',
                          style: TextStyle(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
              height: 1,
              color: AppColors.divider,
              indent: 12,
              endIndent: 12,
            ),
        ],
      ),
    );
  }
}

class _LogbookTotalsRow extends StatelessWidget {
  final int totalLessons;
  final int totalMinutes;
  final String Function(int) hhMm;
  final double filteredHours;

  const _LogbookTotalsRow({
    required this.totalLessons,
    required this.totalMinutes,
    required this.hhMm,
    required this.filteredHours,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevatedDark,
        borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(13)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              'TOTALS',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Text(
              '$totalLessons lesson${totalLessons == 1 ? '' : 's'}',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 42,
            child: Text(
              totalMinutes > 0 ? hhMm(totalMinutes) : '\u2014',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 6 + 40 + 6 + 36),
        ],
      ),
    );
  }
}

class _HoursFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _HoursFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : AppColors.onSurfaceVariant,
            fontSize: 13,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

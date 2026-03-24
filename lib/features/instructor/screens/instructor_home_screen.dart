// Instructor home screen — shows a list of linked students with progress summaries.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/widgets/empty_state_widget.dart';
import '../providers/instructor_provider.dart';

// ---------------------------------------------------------------------------
// Helper: greeting based on hour of day
// ---------------------------------------------------------------------------

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

// ---------------------------------------------------------------------------
// InstructorHomeScreen
// ---------------------------------------------------------------------------

class InstructorHomeScreen extends ConsumerStatefulWidget {
  const InstructorHomeScreen({super.key});

  @override
  ConsumerState<InstructorHomeScreen> createState() =>
      _InstructorHomeScreenState();
}

class _InstructorHomeScreenState extends ConsumerState<InstructorHomeScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'instructor_home_opened');
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final studentsAsync = ref.watch(linkedStudentProfilesProvider);

    return Scaffold(
      
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userAsync.valueOrNull?.displayName ?? 'Instructor',
                      style:  TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Instructor',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Quick Actions ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.qr_code_rounded,
                        label: 'My Invite Code',
                        onTap: () => context.push('/instructor/invite-code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.person_add_rounded,
                        label: 'Add Student',
                        onTap: () => context.push('/instructor/invite-code'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.chat_rounded,
                        label: 'Messages',
                        onTap: () {
                          final students =
                              ref.read(linkedStudentProfilesProvider).valueOrNull ?? [];
                          if (students.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No linked students to message.'),
                              ),
                            );
                          } else if (students.length == 1) {
                            context.push(
                              '/instructor/messaging/${students.first.uid}'
                              '?name=${Uri.encodeComponent(students.first.displayName)}',
                            );
                          } else {
                            showModalBottomSheet<void>(
                              context: context,
                              builder: (ctx) => _StudentPickerSheet(
                                students: students,
                                onPick: (student) {
                                  Navigator.pop(ctx);
                                  context.push(
                                    '/instructor/messaging/${student.uid}'
                                    '?name=${Uri.encodeComponent(student.displayName)}',
                                  );
                                },
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section header ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                     Text(
                      'MY STUDENTS',
                      style: TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const Spacer(),
                    studentsAsync.when(
                      data: (students) => Text(
                        '${students.length} linked',
                        style:  TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),

            // ── Student list ─────────────────────────────────────────────
            studentsAsync.when(
              data: (students) {
                if (students.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: EmptyStateWidget(
                      icon: Icons.people_outline_rounded,
                      title: 'No students yet',
                      subtitle:
                          'Share your invite code with students to link them to your account.',
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _StudentCard(
                          student: students[index],
                          onTap: () => context.push(
                            '/instructor/student/${students[index].uid}',
                          ),
                        ),
                      ),
                      childCount: students.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Failed to load students. Please try again.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick action card
// ---------------------------------------------------------------------------

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style:  TextStyle(
                color: AppColors.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Student card
// ---------------------------------------------------------------------------

class _StudentCard extends StatelessWidget {
  final AppUser student;
  final VoidCallback onTap;

  const _StudentCard({required this.student, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = student.displayName.isNotEmpty
        ? student.displayName[0].toUpperCase()
        : 'S';

    final aircraftLabel = _aircraftLabel(student.aircraftType);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.2),
              child: Text(
                initial,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.displayName,
                    style:  TextStyle(
                      color: AppColors.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$aircraftLabel  |  ${student.hoursFlown.toStringAsFixed(1)} hrs',
                    style:  TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (student.flightSchool.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      student.flightSchool,
                      style:  TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
             Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _aircraftLabel(String type) {
    switch (type) {
      case 'cessna_152':
        return 'C152';
      case 'cessna_172':
        return 'C172';
      case 'pa28':
        return 'PA-28';
      case 'da40':
        return 'DA40';
      default:
        return type.isNotEmpty ? type : 'N/A';
    }
  }
}

// ---------------------------------------------------------------------------
// Student picker sheet — shown when an instructor has multiple students and
// taps Messages, letting them choose who to open a conversation with.
// ---------------------------------------------------------------------------

class _StudentPickerSheet extends StatelessWidget {
  final List<AppUser> students;
  final void Function(AppUser student) onPick;

  const _StudentPickerSheet({
    required this.students,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Message a Student',
              style: TextStyle(
                color: AppColors.onSurface,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Divider(height: 1),
          ...students.map(
            (student) => ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                child: Text(
                  student.displayName.isNotEmpty
                      ? student.displayName[0].toUpperCase()
                      : 'S',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(student.displayName),
              subtitle: Text(student.email),
              trailing: const Icon(
                Icons.chat_rounded,
                color: AppColors.primary,
              ),
              onTap: () => onPick(student),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

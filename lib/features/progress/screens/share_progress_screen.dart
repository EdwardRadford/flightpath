// Share progress screen — generates a shareable link or summary of the
// student's training progress.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/features/lesson_log/providers/lesson_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/user_exercise.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

/// Generates a 32-character hex token using a cryptographically secure RNG.
String _generateToken() {
  final rand = Random.secure();
  return List.generate(32, (_) => rand.nextInt(16).toRadixString(16)).join();
}

class ShareProgressScreen extends ConsumerStatefulWidget {
  const ShareProgressScreen({super.key});

  @override
  ConsumerState<ShareProgressScreen> createState() =>
      _ShareProgressScreenState();
}

class _ShareProgressScreenState extends ConsumerState<ShareProgressScreen> {
  bool _generating = false;
  bool _revoking = false;
  bool _loadingLink = true;
  Map<String, dynamic>? _activeLink;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'share_progress_opened');
    _loadActiveLink();
  }

  Future<void> _loadActiveLink() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) {
      setState(() => _loadingLink = false);
      return;
    }
    final firestore = ref.read(firestoreServiceProvider);
    final link = await firestore.getActiveShareLink(uid);
    if (!mounted) return;
    setState(() {
      _activeLink = link;
      _loadingLink = false;
    });
  }

  Future<void> _generateLink() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    FirebaseAnalytics.instance.logEvent(name: 'share_progress_tapped');
    setState(() => _generating = true);

    try {
      final firestore = ref.read(firestoreServiceProvider);
      final token = _generateToken();
      await firestore.createShareLink(uid, token);

      FirebaseAnalytics.instance.logEvent(name: 'share_link_generated');

      final url = 'https://getflightpath.app/progress/$token';

      if (!mounted) return;
      setState(() {
        _activeLink = {
          'share_token': token,
          'created_at': Timestamp.fromDate(DateTime.now()),
          'expires_at': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30)),
          ),
          'is_active': true,
        };
        _generating = false;
      });

      await SharePlus.instance.share(ShareParams(text: url));
    } catch (e) {
      if (!mounted) return;
      setState(() => _generating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate link. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _revokeLink() async {
    final token = _activeLink?['share_token'] as String?;
    if (token == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Revoke Share Link',
          style: TextStyle(color: AppColors.onSurface),
        ),
        content: Text(
          'This will deactivate the link. Anyone with the link will no longer '
          'be able to view your progress.',
          style: TextStyle(color: AppColors.onSurfaceVariant, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Revoke',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _revoking = true);

    try {
      final firestore = ref.read(firestoreServiceProvider);
      await firestore.revokeShareLink(token);

      FirebaseAnalytics.instance.logEvent(name: 'share_link_revoked');

      if (!mounted) return;
      setState(() {
        _activeLink = null;
        _revoking = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Share link revoked.'),
          backgroundColor: AppColors.surfaceVariant,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _revoking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to revoke link. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  String _compositeId(Lesson lesson) {
    if (lesson.subExercise.isNotEmpty) {
      return '${lesson.exerciseId}_${lesson.subExercise}';
    }
    return lesson.exerciseId;
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final lessonsAsync = ref.watch(allLessonsProvider);
    final exercisesAsync = ref.watch(userExercisesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share with Instructor'),
        elevation: 0,
      ),
      body: userAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (_, __) => const Center(
          child: Text('Unable to load data. Please try again.',
              style: TextStyle(color: AppColors.error)),
        ),
        data: (user) {
          final lessons = lessonsAsync.valueOrNull ?? [];
          final exercises = exercisesAsync.valueOrNull ?? <UserExercise>[];

          final completedLessons =
              lessons.where((l) => l.status == LessonStatus.completed).toList();

          final completedExercises =
              exercises.where((e) => e.status.isCompleted).length;

          final ratedLessons = completedLessons
              .where((l) => l.studentRating != null)
              .toList();
          final avgRating = ratedLessons.isNotEmpty
              ? ratedLessons.fold<double>(
                      0, (total, l) => total + l.studentRating!) /
                  ratedLessons.length
              : 0.0;

          final sortedLessons = [...completedLessons]
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final last5 = sortedLessons.take(5).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // Privacy notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Personal reflections and AI debrief content are never shared.',
                        style: TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Preview header
              Text(
                'SHARE PREVIEW',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              // Summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Student Pilot',
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SummaryRow(
                      label: 'Total Hours',
                      value:
                          '${user?.hoursFlown.toStringAsFixed(1) ?? '0.0'} hrs',
                    ),
                    Divider(color: AppColors.divider, height: 20),
                    _SummaryRow(
                      label: 'Exercises Completed',
                      value:
                          '$completedExercises / ${AppConstants.allExerciseIds.length}',
                    ),
                    Divider(color: AppColors.divider, height: 20),
                    _SummaryRow(
                      label: 'Average Rating',
                      value: avgRating > 0
                          ? '${avgRating.toStringAsFixed(1)} / 5'
                          : 'N/A',
                    ),
                    Divider(color: AppColors.divider, height: 20),
                    _SummaryRow(
                      label: 'Lessons Completed',
                      value: '${completedLessons.length}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Last 5 lessons
              if (last5.isNotEmpty) ...[
                Text(
                  'RECENT LESSONS',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < last5.length; i++) ...[
                        _RecentLessonTile(
                          lesson: last5[i],
                          exerciseName:
                              exerciseDisplayName(_compositeId(last5[i])),
                        ),
                        if (i < last5.length - 1)
                          Divider(
                            color: AppColors.divider,
                            height: 1,
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // GDPR notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'By generating a link, you agree that your lesson history '
                  'will be accessible to anyone with the link for 30 days.',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Active link info / Generate button
              if (_loadingLink)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_activeLink != null) ...[
                _ActiveLinkCard(
                  token: _activeLink!['share_token'] as String,
                  expiresAt:
                      (_activeLink!['expires_at'] as Timestamp).toDate(),
                  revoking: _revoking,
                  onRevoke: _revokeLink,
                  onShare: () async {
                    FirebaseAnalytics.instance
                        .logEvent(name: 'share_progress_tapped');
                    final url =
                        'https://getflightpath.app/progress/${_activeLink!['share_token']}';
                    await SharePlus.instance.share(ShareParams(text: url));
                  },
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _generating ? null : _generateLink,
                    icon: _generating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      _generating ? 'Generating...' : 'Generate Share Link',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary row widget
// ---------------------------------------------------------------------------
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppColors.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Recent lesson tile
// ---------------------------------------------------------------------------
class _RecentLessonTile extends StatelessWidget {
  final Lesson lesson;
  final String exerciseName;

  const _RecentLessonTile({
    required this.lesson,
    required this.exerciseName,
  });

  @override
  Widget build(BuildContext context) {
    final date = lesson.lessonDate ?? lesson.createdAt;
    final dateStr = DateFormat('d MMM yyyy').format(date);
    final rating = lesson.studentRating;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseName,
                  style: TextStyle(
                    color: AppColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (rating != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _ratingColor(rating).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$rating/5',
                style: TextStyle(
                  color: _ratingColor(rating),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _ratingColor(int rating) {
    if (rating >= 4) return AppColors.success;
    if (rating >= 3) return AppColors.warning;
    return AppColors.error;
  }
}

// ---------------------------------------------------------------------------
// Active link card
// ---------------------------------------------------------------------------
class _ActiveLinkCard extends StatelessWidget {
  final String token;
  final DateTime expiresAt;
  final bool revoking;
  final VoidCallback onRevoke;
  final VoidCallback onShare;

  const _ActiveLinkCard({
    required this.token,
    required this.expiresAt,
    required this.revoking,
    required this.onRevoke,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final url = 'https://getflightpath.app/progress/$token';
    final expiryStr = DateFormat('d MMM yyyy').format(expiresAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.link_rounded, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                'Active Share Link',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              url,
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Expires: $expiryStr',
            style: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: revoking ? null : onRevoke,
                  icon: revoking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.error,
                          ),
                        )
                      : const Icon(Icons.link_off_rounded,
                          size: 18, color: AppColors.error),
                  label: Text(
                    revoking ? 'Revoking...' : 'Revoke',
                    style: const TextStyle(color: AppColors.error),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

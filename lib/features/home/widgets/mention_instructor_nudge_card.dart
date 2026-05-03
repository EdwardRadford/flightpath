import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/home/providers/home_provider.dart';
import 'package:flight_path/shared/models/lesson.dart';

final _nudgeStateProvider = FutureProvider<_NudgeState?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final db = FirebaseFirestore.instance;
  // Get most recent lesson
  final snap = await db
      .collection('users')
      .doc(uid)
      .collection('lessons')
      .orderBy('created_at', descending: true)
      .limit(2)
      .get();

  if (snap.docs.isEmpty) return null;

  final mostRecent = Lesson.fromFirestore(snap.docs.first);
  if (mostRecent.aiMentionToInstructor.isEmpty) return null;
  // Check if dismissed
  if (snap.docs.first.data()['mention_dismissed_at'] != null) return null;

  // Check no lesson logged since (i.e. this is the most recent)
  // Since we fetched limit 2, if there are 2 docs the 2nd is older —
  // mostRecent is already the newest, so nudge is valid.

  return _NudgeState(
    lessonId: mostRecent.id,
    exerciseId: mostRecent.exerciseId,
    mentionText: mostRecent.aiMentionToInstructor,
    instructorName: mostRecent.instructorName,
    lesson: mostRecent,
  );
});

class _NudgeState {
  final String lessonId;
  final String exerciseId;
  final String mentionText;
  final String instructorName;
  final Lesson lesson;
  const _NudgeState({
    required this.lessonId,
    required this.exerciseId,
    required this.mentionText,
    required this.instructorName,
    required this.lesson,
  });
}

class MentionInstructorNudgeCard extends ConsumerWidget {
  const MentionInstructorNudgeCard({super.key});

  Future<void> _dismiss(String lessonId, String uid) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('lessons')
        .doc(lessonId)
        .update({'mention_dismissed_at': FieldValue.serverTimestamp()});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nudgeAsync = ref.watch(_nudgeStateProvider);
    final cs = Theme.of(context).colorScheme;

    return nudgeAsync.when(
      data: (state) {
        if (state == null) return const SizedBox.shrink();
        final instructorLabel = state.instructorName.isNotEmpty
            ? state.instructorName
            : 'your instructor';

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Worth mentioning to $instructorLabel next session',
                        style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Semantics(
                      label: 'Dismiss instructor mention nudge',
                      button: true,
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.5),
                        ),
                        onPressed: () {
                          final uid =
                              FirebaseAuth.instance.currentUser?.uid ?? '';
                          _dismiss(state.lessonId, uid);
                          ref.invalidate(_nudgeStateProvider);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Semantics(
                  label: 'View lesson: ${state.mentionText}',
                  button: true,
                  child: GestureDetector(
                    onTap: () => context.push(
                      '/lesson-detail',
                      extra: state.lesson,
                    ),
                    child: Text(
                      state.mentionText,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';

// Provider to read user exercise statuses — read from Firestore.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

final _soloMilestoneProvider = FutureProvider<_SoloState?>((ref) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return null;

  final db = FirebaseFirestore.instance;
  final ex12 = await db
      .collection('users')
      .doc(uid)
      .collection('user_exercises')
      .doc('ex_12')
      .get();
  final ex14 = await db
      .collection('users')
      .doc(uid)
      .collection('user_exercises')
      .doc('ex_14')
      .get();

  final ex12Completed = ex12.data()?['status'] == 'completed';
  final ex14Completed = ex14.data()?['status'] == 'completed';

  if (!ex12Completed || ex14Completed) return null;

  // Count exercises before solo (1-13)
  final allSnap = await db
      .collection('users')
      .doc(uid)
      .collection('user_exercises')
      .get();
  int completed = 0;
  for (final doc in allSnap.docs) {
    final parts = doc.id.split('_');
    if (parts.length >= 2) {
      final num = int.tryParse(parts[1]) ?? 0;
      if (num <= 13 && doc.data()['status'] == 'completed') completed++;
    }
  }

  return _SoloState(completedCount: completed);
});

class _SoloState {
  final int completedCount;
  const _SoloState({required this.completedCount});
}

class FirstSoloMilestoneCard extends ConsumerWidget {
  const FirstSoloMilestoneCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soloAsync = ref.watch(_soloMilestoneProvider);
    final cs = Theme.of(context).colorScheme;

    final tt = Theme.of(context).textTheme;
    return soloAsync.when(
      data: (state) {
        if (state == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            label: 'Approaching first solo milestone',
            child: GestureDetector(
              onTap: () => context.push('/exercises/pre-solo-readiness'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_rounded,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Approaching first solo',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                                fontWeight: FontWeight.w600,
                              )),
                          Text('${state.completedCount}/13 pre-solo exercises complete',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelLarge?.copyWith(
                                color: cs.onSurface.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w400,
                                letterSpacing: 0,
                              )),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.3),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

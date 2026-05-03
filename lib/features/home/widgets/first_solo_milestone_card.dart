import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';

// Provider to read user exercise statuses — read from Firestore
// Uses the appUserProvider to get uid, then reads user_exercises subcollection.
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

    return soloAsync.when(
      data: (state) {
        if (state == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Semantics(
            label: 'Approaching first solo milestone',
            child: GestureDetector(
              onTap: () => context.push('/exercises/pre-solo-readiness'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Approaching first solo',
                      style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'You\'ve completed ${state.completedCount}/13 exercises before solo. '
                      'Pre-Solo Readiness Check awaits when your instructor signs you off.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
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

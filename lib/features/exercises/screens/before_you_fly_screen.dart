// Before You Fly screen — loaded from exerciseContentProvider, marks the exercise viewed on first load.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/features/exercises/providers/exercise_provider.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/utils/exercise_helpers.dart';

class BeforeYouFlyScreen extends ConsumerStatefulWidget {
  final String compositeExerciseId;

  const BeforeYouFlyScreen({super.key, required this.compositeExerciseId});

  @override
  ConsumerState<BeforeYouFlyScreen> createState() => _BeforeYouFlyScreenState();
}

class _BeforeYouFlyScreenState extends ConsumerState<BeforeYouFlyScreen> {
  bool _viewedMarked = false;

  @override
  Widget build(BuildContext context) {
    final (exerciseId, subExerciseId) =
        parseExerciseId(widget.compositeExerciseId);
    final contentAsync =
        ref.watch(exerciseContentProvider((exerciseId, subExerciseId)));

    if (!_viewedMarked && contentAsync.hasValue && contentAsync.value != null) {
      _viewedMarked = true;
      // Deferred to avoid mutating provider state during a build call.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        markBeforeYouFlyViewed(ref, exerciseId, subExerciseId);
      });
    }

    return contentAsync.when(
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Could not load content')),
      ),
      data: (content) {
        if (content == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Content not found')),
          );
        }
        return _BeforeYouFlyBody(content: content);
      },
    );
  }
}

class _BeforeYouFlyBody extends StatelessWidget {
  final ExerciseContent content;

  const _BeforeYouFlyBody({required this.content});

  List<String> _splitLines(String text) => text
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();

  @override
  Widget build(BuildContext context) {
    final focusLines = _splitLines(content.keyFocusAreas);
    final recallLines = _splitLines(content.activeRecallPrompt);
    final mistakeLines = _splitLines(content.commonMistakes);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.exerciseName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
            Text(
              'Before You Fly',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (content.whatToExpect.isNotEmpty) ...[
            _SectionCard(
              title: "Today's lesson",
              child: Text(
                content.whatToExpect,
                style: TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (focusLines.isNotEmpty) ...[
            _SectionCard(
              title: 'Focus on',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: focusLines.map((line) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (recallLines.isNotEmpty) ...[
            _SectionCard(
              title: 'Think about this',
              accentColor: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: recallLines.map((line) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4, right: 8),
                          child: Icon(
                            Icons.arrow_right_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (mistakeLines.isNotEmpty) ...[
            _SectionCard(
              title: 'Watch out for',
              accentColor: AppColors.warning,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: mistakeLines.map((line) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, right: 10),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontSize: 14,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.pushReplacement('/tools/weather'),
              icon: const Icon(Icons.cloud_rounded),
              label: const Text(
                'Next: Weather',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: () => context.pop(),
              child: Text(
                'Back to Exercise',
                style: TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? accentColor;

  const _SectionCard({
    required this.title,
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent != null
              ? accent.withValues(alpha: 0.3)
              : cs.outline,
          width: accent != null ? 1.0 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent ?? cs.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

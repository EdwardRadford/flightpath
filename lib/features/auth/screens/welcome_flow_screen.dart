import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/constants/app_constants.dart';
import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/services/welcome_service.dart';

class WelcomeFlowScreen extends ConsumerStatefulWidget {
  const WelcomeFlowScreen({super.key});

  @override
  ConsumerState<WelcomeFlowScreen> createState() => _WelcomeFlowScreenState();
}

class _WelcomeFlowScreenState extends ConsumerState<WelcomeFlowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _skip() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) await WelcomeService.markCompleted(user.uid);
    if (!mounted) return;
    context.go('/home');
  }

  Future<void> _complete(AppUser user) async {
    await WelcomeService.markCompleted(user.uid);
    if (!mounted) return;
    // Navigate to the user's current exercise
    final exNum = user.currentExerciseNumber;
    final exId = 'ex_${exNum.toString().padLeft(2, '0')}';
    context.go('/exercises/$exId');
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserProvider);
    final cs = Theme.of(context).colorScheme;

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Continue to app'),
          ),
        ),
      ),
      data: (user) {
        if (user == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
          return const Scaffold(body: SizedBox.shrink());
        }

        final firstName = user.displayName.split(' ').first.isNotEmpty
            ? user.displayName.split(' ').first
            : 'there';
        final aircraftLabel =
            AppConstants.aircraftTypes[user.aircraftType] ?? user.aircraftType;
        final exNum = user.currentExerciseNumber;
        final exId = 'ex_${exNum.toString().padLeft(2, '0')}';
        final exTitle = AppConstants.exerciseTitles[exId] ?? 'your next exercise';

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            actions: [
              if (_currentPage < 2)
                TextButton(
                  onPressed: _skip,
                  child: Text('Skip',
                      style: TextStyle(
                          color: cs.onSurface.withValues(alpha: 0.6))),
                ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _WelcomePage(
                      content: 'Welcome, $firstName.\n\n'
                          "You're training in a $aircraftLabel"
                          '${user.airfieldIcao.isNotEmpty ? " from ${user.airfieldIcao}" : ""}. '
                          'We\'ll start at Exercise $exNum: $exTitle.',
                    ),
                    const _WelcomePage(
                      content: 'Three things you\'ll do most:\n\n'
                          '• Prep before each lesson — Brief, Flashcards, Before You Fly\n'
                          '• Debrief after — log the flight and talk it through with the AI Instructor\n'
                          '• Track your progress — every exercise builds toward your skills test\n\n'
                          'They\'re all one tap away from your home screen.',
                    ),
                    _WelcomePage(
                      content: '',
                      cta: 'Open Exercise $exNum: $exTitle',
                      onCta: () => _complete(user),
                    ),
                  ],
                ),
              ),
              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _currentPage ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == _currentPage
                            ? AppColors.primary
                            : cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
              if (_currentPage < 2)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      24, 0, 24, 16 + MediaQuery.of(context).padding.bottom),
                  child: Semantics(
                    label: 'Next',
                    button: true,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final String content;
  final String? cta;
  final VoidCallback? onCta;

  const _WelcomePage({required this.content, this.cta, this.onCta});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (content.isNotEmpty)
            Text(
              content,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 17,
                height: 1.6,
              ),
            ),
          if (cta != null) ...[
            const SizedBox(height: 32),
            Text(
              'Ready to start?',
              style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              label: cta!,
              button: true,
              child: ElevatedButton(
                onPressed: onCta,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(cta!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

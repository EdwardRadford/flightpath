// Welcome onboarding flow — 3-screen PageView shown to first-time users
// before the signup screen. Stores a SharedPreferences flag so it only
// appears once. This is the inspiring, aviation-themed introduction that
// makes students feel like they're starting an adventure.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/core/utils/router.dart';

/// Key used in SharedPreferences to track whether the welcome flow has been shown.
const String kHasSeenOnboardingKey = 'has_seen_onboarding';

/// Data class for each welcome page.
class _WelcomePage {
  final IconData icon;
  final String headline;
  final String subtext;
  /// If true, this page uses a custom flow diagram instead of the standard icon.
  final bool isFlowPage;

  const _WelcomePage({
    required this.icon,
    required this.headline,
    required this.subtext,
    this.isFlowPage = false,
  });
}

const _pages = [
  _WelcomePage(
    icon: Icons.flight_takeoff,
    headline: 'Welcome to Flight Path Training',
    subtext:
        'Your personal companion through the PPL(A) syllabus — from first '
        'lesson to skills test.',
  ),
  _WelcomePage(
    icon: Icons.loop_rounded,
    headline: 'How It Works',
    subtext: 'Each exercise follows a simple cycle',
    isFlowPage: true,
  ),
  _WelcomePage(
    icon: Icons.explore_rounded,
    headline: 'Ready for Takeoff',
    subtext:
        'Exercises 1–3 are free. Unlock all 19 exercises, AI-powered debriefs, '
        'and the full question bank with a one-time Pro upgrade — £49.99.\n\n'
        'Create your account to get started.',
  ),
];

/// Three-screen welcome flow with swipeable pages, dot indicators,
/// Skip/Next buttons, and a "Get Started" CTA on the final page.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kHasSeenOnboardingKey, true);
    if (!mounted) return;
    // Invalidate the cached provider so the router re-evaluates redirects.
    ref.invalidate(onboardingCompleteProvider);
    context.go('/signup');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button — visible on pages 1 and 2 only
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: AnimatedOpacity(
                  opacity: isLastPage ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: isLastPage ? null : _completeWelcome,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (index) =>
                    setState(() => _currentPage = index),
                itemBuilder: (context, index) =>
                    _PageContent(page: _pages[index]),
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => _DotIndicator(isActive: i == _currentPage),
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                child: isLastPage
                    ? ElevatedButton(
                        onPressed: _completeWelcome,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBright,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Get Started'),
                      )
                    : ElevatedButton(
                        onPressed: _nextPage,
                        child: const Text('Next'),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual page content — large icon with glowing background, headline,
/// and descriptive subtext.
class _PageContent extends StatelessWidget {
  final _WelcomePage page;

  const _PageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (page.isFlowPage) ...[
            // Flow diagram: Schedule → Prepare → Fly → Debrief
            const _LessonFlowDiagram(),
          ] else ...[
            // Icon with circular gradient glow
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.25),
                    AppColors.primary.withValues(alpha: 0.08),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: Center(
                child: Icon(
                  page.icon,
                  size: 96,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 48),

          // Headline
          Text(
            page.headline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 20),

          // Subtext
          Text(
            page.subtext,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

/// Visual flow diagram showing the lesson cycle:
/// Schedule → Prepare → Fly → Debrief
class _LessonFlowDiagram extends StatelessWidget {
  const _LessonFlowDiagram();

  static const _steps = [
    (icon: Icons.calendar_today_rounded, label: 'Schedule'),
    (icon: Icons.menu_book_rounded, label: 'Prepare'),
    (icon: Icons.flight_rounded, label: 'Fly'),
    (icon: Icons.rate_review_rounded, label: 'Debrief'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < _steps.length; i++) ...[
          _FlowStep(icon: _steps[i].icon, label: _steps[i].label),
          if (i < _steps.length - 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 24,
              ),
            ),
        ],
      ],
    );
  }
}

/// A single step in the lesson flow diagram.
class _FlowStep extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FlowStep({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
          child: Center(
            child: Icon(icon, size: 28, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

/// Animated dot indicator for the current page.
class _DotIndicator extends StatelessWidget {
  final bool isActive;

  const _DotIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isActive ? 28 : 10,
      height: 10,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        color: isActive
            ? AppColors.primary
            : Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.15),
      ),
    );
  }
}

// Full-screen page-by-page app tour dialog.
// Shows one page per main tab explaining what each section does.
import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_theme.dart';

/// Data for a single tour page.
class _TourPage {
  final IconData icon;
  final String title;
  final String description;

  const _TourPage({
    required this.icon,
    required this.title,
    required this.description,
  });
}

const _pages = [
  _TourPage(
    icon: Icons.waving_hand_rounded,
    title: 'Welcome to Flight Path',
    description:
        'Your personal PPL(A) training companion. '
        'Let\u2019s take a quick look at what\u2019s inside.',
  ),
  _TourPage(
    icon: Icons.home_rounded,
    title: 'Home',
    description:
        'Your dashboard shows your next lesson, quick stats, '
        'a daily revision question, and your recent activity.',
  ),
  _TourPage(
    icon: Icons.list_rounded,
    title: 'Exercises',
    description:
        'All 19 CAA exercises in order. Tap any exercise to prepare \u2014 '
        'read the brief, watch videos, practice flashcards, and take quizzes.',
  ),
  _TourPage(
    icon: Icons.auto_awesome_rounded,
    title: 'Ask AI',
    description:
        'Chat with your AI flight instructor. Ask about theory, procedures, '
        'weather, or anything from your training.',
  ),
  _TourPage(
    icon: Icons.menu_book_rounded,
    title: 'Logbook',
    description:
        'Log your lessons and track your hours. After each flight, debrief '
        'and get AI-generated feedback on what went well and what to improve.',
  ),
  _TourPage(
    icon: Icons.settings_rounded,
    title: 'Settings',
    description:
        'Edit your profile, link your instructor, adjust accessibility, '
        'export your data, and manage your account.',
  ),
];

/// Shows a full-screen page-by-page app tour.
///
/// Returns `true` if the user completed or skipped the tour.
Future<bool> showAppTourDialog(BuildContext context) async {
  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, anim, secondaryAnim, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: child,
      );
    },
    pageBuilder: (ctx, _, __) => const _AppTourDialog(),
  );
  return result ?? false;
}

class _AppTourDialog extends StatefulWidget {
  const _AppTourDialog();

  @override
  State<_AppTourDialog> createState() => _AppTourDialogState();
}

class _AppTourDialogState extends State<_AppTourDialog> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).pop(true);
    }
  }

  void _skip() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page content
                SizedBox(
                  height: 320,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (ctx, i) {
                      final page = _pages[i];
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
                        child: Column(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                page.icon,
                                color: AppColors.primary,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              page.title,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.description,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 15,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Dots + buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      // Dot indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: isActive ? 20 : 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      // Buttons row
                      Row(
                        children: [
                          TextButton(
                            onPressed: _skip,
                            style: TextButton.styleFrom(
                              foregroundColor: textColor.withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            child: const Text('Skip'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _next,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _currentPage == _pages.length - 1
                                  ? 'Get Started'
                                  : 'Next',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

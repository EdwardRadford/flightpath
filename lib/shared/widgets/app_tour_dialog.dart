import 'package:flutter/material.dart';

import 'package:flight_path/core/theme/app_icons.dart';
import 'package:flight_path/core/theme/app_theme.dart';

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
    icon: AppIcons.tour,
    title: 'Welcome to Flight Path Training',
    description:
        'Your personal PPL(A) training companion. '
        'Let\u2019s take a quick look at what\u2019s inside.',
  ),
  _TourPage(
    icon: AppIcons.home,
    title: 'Home',
    description:
        'Your dashboard shows your next lesson, quick stats, '
        'and your recent activity.',
  ),
  _TourPage(
    icon: AppIcons.exercises,
    title: 'Exercises',
    description:
        'All CAA exercises in order. Tap any exercise to prepare \u2014 '
        'read the brief, practice flashcards, and chat with your AI instructor.',
  ),
  _TourPage(
    icon: AppIcons.menuBook,
    title: 'Logbook',
    description:
        'Log every lesson and track your hours toward CAA minimums. '
        'After each flight, get AI-generated feedback on what went well and what to improve.',
  ),
  _TourPage(
    icon: AppIcons.learn,
    title: 'Learn',
    description:
        'Sharpen your radio work with AI ATC roleplay across 9 real scenarios, '
        'and decode ATIS broadcasts with guided UK examples.',
  ),
  _TourPage(
    icon: AppIcons.tools,
    title: 'Tools',
    description:
        'Aircraft performance data, UK airfield information, live METAR training, '
        'a QXC planning guide, and weather briefings \u2014 all in one place.',
  ),
  _TourPage(
    icon: AppIcons.settings,
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
  final result = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute<bool>(
      fullscreenDialog: true,
      builder: (ctx) => const _AppTourPage(),
    ),
  );
  return result ?? false;
}

class _AppTourPage extends StatefulWidget {
  const _AppTourPage();

  @override
  State<_AppTourPage> createState() => _AppTourPageState();
}

class _AppTourPageState extends State<_AppTourPage> {
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
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: textColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (ctx, i) {
                  final page = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            page.icon,
                            color: AppColors.primary,
                            size: 44,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          page.title,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.description,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 16,
                            height: 1.55,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                children: [
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
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

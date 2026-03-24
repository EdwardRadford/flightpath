// Bottom navigation shell — wraps tab screens with a persistent nav bar.
// 5 tabs for students: Home | Exercises | Ask AI | Logbook | Settings
// 4 tabs for instructors: Dashboard | Exercises | Logbook | Settings
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/update_badge_provider.dart';
import 'package:flight_path/shared/widgets/connectivity_banner.dart';

typedef _Tab = ({String path, String label, IconData icon, IconData activeIcon});

/// Scaffold wrapper that provides the bottom navigation bar for shell routes.
/// Animates tab switches directionally — tapping a tab to the left slides the
/// new screen in from the left; tapping a tab to the right slides from the right.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const List<_Tab> _studentTabs = [
    (path: '/home', label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    (path: '/exercises', label: 'Exercises', icon: Icons.list_outlined, activeIcon: Icons.list),
    (path: '/ask-ai', label: 'Ask AI', icon: Icons.auto_awesome_outlined, activeIcon: Icons.auto_awesome_rounded),
    (path: '/logbook', label: 'Logbook', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
    (path: '/settings', label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  static const List<_Tab> _instructorTabs = [
    (path: '/instructor', label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard),
    (path: '/exercises', label: 'Exercises', icon: Icons.list_outlined, activeIcon: Icons.list),
    (path: '/logbook', label: 'Logbook', icon: Icons.menu_book_outlined, activeIcon: Icons.menu_book),
    (path: '/settings', label: 'Settings', icon: Icons.settings_outlined, activeIcon: Icons.settings),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Index of the tab that was active before the most recent navigation.
  /// Used to determine the slide direction of the AnimatedSwitcher.
  int _prevIndex = 0;

  int _currentIndex(BuildContext context, List<_Tab> tabs) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isInstructor = user?.isInstructor ?? false;
    final tabs = isInstructor ? MainShell._instructorTabs : MainShell._studentTabs;
    final index = _currentIndex(context, tabs);
    final showUpdateBadge = ref.watch(updateBadgeProvider);

    // Settings tab index varies by role.
    final settingsIndex = tabs.indexWhere((t) => t.path == '/settings');

    // New tab is to the left of the previous one → slide in from the left.
    final slideFromLeft = index < _prevIndex;

    return Scaffold(
      body: Column(
        children: [
          const ConnectivityBanner(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) {
                final begin = slideFromLeft
                    ? const Offset(-0.06, 0)
                    : const Offset(0.06, 0);
                final slide = Tween<Offset>(begin: begin, end: Offset.zero).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                );
                final fade = Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
                );
                return SlideTransition(
                  position: slide,
                  child: FadeTransition(opacity: fade, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(tabs[index].path),
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (i) {
            FirebaseAnalytics.instance.logEvent(
              name: 'tab_switched',
              parameters: {'tab_name': tabs[i].label.toLowerCase()},
            );
            if (i == settingsIndex) {
              ref.read(updateBadgeProvider.notifier).markSeen();
            }
            // Capture current index before navigating so slideFromLeft
            // is computed correctly on the next build.
            setState(() => _prevIndex = index);
            context.go(tabs[i].path);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: tabs.asMap().entries.map((entry) {
            final i = entry.key;
            final t = entry.value;
            final isSettings = i == settingsIndex;
            final badgeIcon = Badge(
              isLabelVisible: showUpdateBadge,
              smallSize: 7,
              backgroundColor: AppColors.primary,
              child: Icon(t.icon, semanticLabel: t.label),
            );
            final badgeActiveIcon = Badge(
              isLabelVisible: showUpdateBadge,
              smallSize: 7,
              backgroundColor: AppColors.primary,
              child: Icon(t.activeIcon, semanticLabel: t.label),
            );
            return BottomNavigationBarItem(
              icon: isSettings ? badgeIcon : Icon(t.icon, semanticLabel: t.label),
              activeIcon: isSettings ? badgeActiveIcon : Icon(t.activeIcon, semanticLabel: t.label),
              label: t.label,
              tooltip: t.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

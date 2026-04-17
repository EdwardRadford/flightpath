// Bottom navigation shell — wraps tab screens with a persistent nav bar.
// 5 tabs: Home | Exercises | Progress | Learn | Tools
// Settings is accessed via the AppBar icon on each tab.
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flight_path/core/theme/app_theme.dart';
import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/auth_provider.dart';
import 'package:flight_path/shared/providers/update_badge_provider.dart';
import 'package:flight_path/shared/services/firestore_service.dart';
import 'package:flight_path/shared/services/streak_service.dart';
import 'package:flight_path/shared/widgets/connectivity_banner.dart';

typedef _Tab = ({String path, String label, IconData icon, IconData activeIcon});

/// Scaffold wrapper that provides the bottom navigation bar for shell routes.
/// Animates tab switches directionally — tapping a tab to the left slides the
/// new screen in from the left; tapping a tab to the right slides from the right.
class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  /// Global key for the BottomNavigationBar — used by the coach marks
  /// walkthrough to measure nav tab positions.
  static final bottomNavKey = GlobalKey();

  static const List<_Tab> _tabs = [
    (path: '/home', label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    (path: '/exercises', label: 'Exercises', icon: Icons.list_outlined, activeIcon: Icons.list),
    (path: '/logbook', label: 'Progress', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded),
    (path: '/learn', label: 'Learn', icon: Icons.school_outlined, activeIcon: Icons.school_rounded),
    (path: '/tools', label: 'Tools', icon: Icons.handyman_outlined, activeIcon: Icons.handyman_rounded),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  /// Tracks whether the streak update has been fired this app session.
  static bool _streakUpdated = false;

  /// Index of the tab that was active before the most recent navigation.
  /// Used to determine the slide direction of the AnimatedSwitcher.
  int _prevIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateStreak());
  }

  void _updateStreak() {
    if (_streakUpdated) return;
    _streakUpdated = true;
    final uid = ref.read(currentUserIdProvider);
    final user = ref.read(appUserProvider).valueOrNull;
    if (uid == null || user == null) return;
    final firestoreService = ref.read(firestoreServiceProvider);
    StreakService.updateStreakIfNeeded(uid, user, firestoreService);
  }

  int _currentIndex(BuildContext context, List<_Tab> tabs) {
    final location = GoRouterState.of(context).matchedLocation;
    final idx = tabs.indexWhere((t) => location.startsWith(t.path));
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = MainShell._tabs;
    final index = _currentIndex(context, tabs);
    final showUpdateBadge = ref.watch(updateBadgeProvider);

    // New tab is to the left of the previous one → slide in from the left.
    final slideFromLeft = index < _prevIndex;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 48,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        actions: [
          Badge(
            isLabelVisible: showUpdateBadge,
            smallSize: 7,
            backgroundColor: AppColors.primary,
            child: IconButton(
              icon: const Icon(Icons.settings_rounded),
              tooltip: 'Settings',
              onPressed: () {
                ref.read(updateBadgeProvider.notifier).markSeen();
                context.push('/settings');
              },
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
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
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: widget.child,
                  ),
                ),
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
          key: MainShell.bottomNavKey,
          currentIndex: index,
          onTap: (i) {
            FirebaseAnalytics.instance.logEvent(
              name: 'tab_switched',
              parameters: {'tab_name': tabs[i].label.toLowerCase()},
            );
            // Capture current index before navigating so slideFromLeft
            // is computed correctly on the next build.
            setState(() => _prevIndex = index);
            context.go(tabs[i].path);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Theme.of(context).colorScheme.surface,
          selectedItemColor: AppColors.primary,
          unselectedItemColor:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: tabs.map((t) {
            return BottomNavigationBarItem(
              icon: Icon(t.icon, semanticLabel: t.label),
              activeIcon: Icon(t.activeIcon, semanticLabel: t.label),
              label: t.label,
              tooltip: t.label,
            );
          }).toList(),
        ),
      ),
    );
  }
}

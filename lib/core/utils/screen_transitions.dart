// Screen transition utilities — subtle fade+slide transitions for go_router.
// Respects MediaQuery.disableAnimations (set when the user enables
// "Reduce animations" in Settings or the OS accessibility setting).
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Creates a [CustomTransitionPage] with a subtle fade + upward slide.
///
/// Use this in go_router route definitions via [pageBuilder] instead of
/// [builder] to get smooth transitions between screens.
///
/// ```dart
/// GoRoute(
///   path: '/example',
///   pageBuilder: (context, state) => fadeSlideTransition(
///     state: state,
///     child: const ExampleScreen(),
///   ),
/// )
/// ```
CustomTransitionPage<void> fadeSlideTransition({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        ),
      );
    },
  );
}

/// A horizontal slide transition — used for navigating deeper into content
/// (e.g. exercise -> brief -> flashcards).
CustomTransitionPage<void> slideTransition({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 300),
}) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.15, 0),
          end: Offset.zero,
        ).animate(curve),
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.5, end: 1.0).animate(curve),
          child: child,
        ),
      );
    },
  );
}

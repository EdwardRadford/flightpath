// Deep link service — handles incoming app links and custom URL schemes.
//
// Supported deep link patterns:
//   flightpath://exercise/{exerciseId}          → prepare hub
//   flightpath://exercise/{exerciseId}/flashcards → practice/flashcards
//   flightpath://progress/{token}               → shared progress
//   flightpath://lesson/{lessonId}              → lesson detail (fetches from Firestore)
//   https://getflightpath.app/exercise/...          → same as above
//   https://getflightpath.app/progress/...          → same as above
//   https://getflightpath.app/lesson/{lessonId}    → lesson detail
import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service that listens for incoming deep links and converts them to
/// in-app route paths that GoRouter can navigate to.
class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  /// Returns the initial deep link URI if the app was launched via one.
  Future<Uri?> getInitialLink() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (e, st) {
      debugPrint('DeepLinkService: failed to get initial link: $e');
      FirebaseCrashlytics.instance.recordError(
        e, st,
        reason: 'DeepLinkService.getInitialLink failed',
        fatal: false,
      );
      return null;
    }
  }

  /// Stream of deep link URIs received while the app is running.
  Stream<Uri> get onLink => _appLinks.uriLinkStream;

  /// Regex to validate exercise IDs and other path segments — only
  /// alphanumeric characters and underscores are allowed.
  static final RegExp _safeSegment = RegExp(r'^[a-zA-Z0-9_]+$');

  /// Converts a deep link URI to an in-app GoRouter path.
  ///
  /// Returns null if the URI doesn't match any known pattern or contains
  /// suspicious path segments.
  static String? uriToRoute(Uri uri) {
    // Normalise path segments from both custom scheme and https.
    // flightpath://exercise/5       → segments: ['exercise', '5']
    // https://getflightpath.app/exercise/5 → segments: ['exercise', '5']
    final segments = uri.pathSegments;

    if (segments.isEmpty) return null;

    switch (segments[0]) {
      case 'exercise':
        if (segments.length < 2) return null;
        final exerciseId = segments[1];
        // Reject malformed or malicious exercise IDs.
        if (!_safeSegment.hasMatch(exerciseId) || exerciseId.length > 30) {
          return null;
        }
        if (segments.length == 2) {
          // /exercise/{id} → prepare hub
          return '/exercises/$exerciseId';
        }
        if (segments.length >= 3) {
          switch (segments[2]) {
            case 'flashcards':
              return '/exercises/$exerciseId/flashcards';
            case 'brief':
              return '/exercises/$exerciseId/brief';
            case 'visualisation':
              return '/exercises/$exerciseId/visualisation';
            default:
              return '/exercises/$exerciseId';
          }
        }
        return null;

      case 'exercises':
        // Handle /exercises/:id and /exercises/:id/brief|flashcards etc.
        if (segments.length < 2) return '/exercises';
        final exerciseId = segments[1];
        if (!_safeSegment.hasMatch(exerciseId) || exerciseId.length > 30) {
          return null;
        }
        if (segments.length == 2) {
          return '/exercises/$exerciseId';
        }
        if (segments.length >= 3) {
          switch (segments[2]) {
            case 'brief':
              return '/exercises/$exerciseId/brief';
            case 'flashcards':
              return '/exercises/$exerciseId/flashcards';
            case 'visualisation':
              return '/exercises/$exerciseId/visualisation';
            default:
              return '/exercises/$exerciseId';
          }
        }
        return null;

      case 'lesson':
        if (segments.length < 2) return null;
        final lessonId = segments[1];
        // Lesson IDs are Firestore auto-IDs — alphanumeric, up to 20 chars.
        if (!_safeSegment.hasMatch(lessonId) || lessonId.length > 64) {
          return null;
        }
        return '/lesson/$lessonId';

      case 'logbook':
        return '/logbook';

      case 'progress':
        if (segments.length < 2) return '/progress';
        final token = segments[1];
        // Reject tokens with suspicious characters (only hex expected).
        if (!_safeSegment.hasMatch(token) || token.length > 64) {
          return null;
        }
        return '/share-progress?token=$token';

      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Singleton [DeepLinkService].
final deepLinkServiceProvider = Provider<DeepLinkService>(
  (_) => DeepLinkService(),
);

/// Holds the pending deep link route path that should be navigated to once
/// the user is authenticated. Set when a deep link arrives before auth.
/// Cleared after navigation.
final pendingDeepLinkProvider = StateProvider<String?>((ref) => null);

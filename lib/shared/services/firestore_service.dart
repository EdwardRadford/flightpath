// Firestore data-access layer — reads and writes for users, lessons,
// exercises, quiz questions, and share links.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/services/hive_service.dart';
import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/models/exercise_content.dart';
import 'package:flight_path/shared/models/lesson.dart';
import 'package:flight_path/shared/models/flashcard.dart';
import 'package:flight_path/shared/models/quiz_question.dart';
import 'package:flight_path/shared/models/user_exercise.dart';

/// Service layer wrapping all Firestore reads and writes.
/// Use FirestoreService via a Riverpod Provider — do not instantiate directly
/// in UI code.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Pre-compiled regex for UID validation — avoids re-compiling on every call.
  static final RegExp _uidPattern = RegExp(r'^[a-zA-Z0-9]+$');

  /// Validates that a uid is non-empty and looks like a Firebase Auth UID.
  void _assertValidUid(String uid) {
    if (uid.isEmpty) {
      throw ArgumentError('uid must not be empty');
    }
    // Firebase Auth UIDs are typically 28 alphanumeric chars.
    if (uid.length > 128 || !_uidPattern.hasMatch(uid)) {
      throw ArgumentError('uid contains invalid characters');
    }
  }

  // ---------------------------------------------------------------------------
  // Collections — new schema paths
  // ---------------------------------------------------------------------------

  /// Top-level users collection.
  CollectionReference<Map<String, dynamic>> get usersCollection =>
      _db.collection('users');

  /// Per-user lessons subcollection: `users/{uid}/lessons`.
  CollectionReference<Map<String, dynamic>> lessonsCollection(String uid) =>
      _db.collection('users').doc(uid).collection('lessons');

  /// Per-user exercises subcollection: `users/{uid}/exercises`.
  CollectionReference<Map<String, dynamic>> exercisesCollection(String uid) =>
      _db.collection('users').doc(uid).collection('exercises');

  /// Read-only exercise content collection (unchanged).
  CollectionReference<Map<String, dynamic>> get exerciseContentCollection =>
      _db.collection('exercise_content');

  /// Read-only quiz questions collection (unchanged).
  CollectionReference<Map<String, dynamic>> get quizQuestionsCollection =>
      _db.collection('quiz_questions');

  /// Read-only flashcards collection.
  CollectionReference<Map<String, dynamic>> get flashcardsCollection =>
      _db.collection('flashcards');

  /// Top-level share links collection.
  CollectionReference<Map<String, dynamic>> get shareLinksCollection =>
      _db.collection('share_links');

  /// Top-level conversations collection.
  CollectionReference<Map<String, dynamic>> get conversationsCollection =>
      _db.collection('conversations');

  /// Messages subcollection within a conversation: `conversations/{id}/messages`.
  CollectionReference<Map<String, dynamic>> messagesCollection(
          String conversationId) =>
      _db.collection('conversations').doc(conversationId).collection('messages');

  // ---------------------------------------------------------------------------
  // Document ID helpers
  // ---------------------------------------------------------------------------

  /// exercise_content doc ID: "ex_01" or "ex_10_10a"
  String _exerciseContentDocId(String exerciseId, {String? subExerciseId}) {
    if (subExerciseId == null) return exerciseId;
    return '${exerciseId}_$subExerciseId';
  }

  /// exercises subcollection doc ID: "ex_01" or "ex_10_10a"
  String _exerciseDocId(String exerciseId, {String? subExerciseId}) {
    if (subExerciseId == null) return exerciseId;
    return '${exerciseId}_$subExerciseId';
  }

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  /// Streams the AppUser document for [uid]. Emits null if the doc is missing.
  Stream<AppUser?> userStream(String uid) {
    _assertValidUid(uid);
    return usersCollection.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return AppUser.fromFirestore(snap);
    });
  }

  /// One-shot fetch of an AppUser. Returns null if not found.
  Future<AppUser?> getUser(String uid) async {
    _assertValidUid(uid);
    final snap = await usersCollection.doc(uid).get();
    if (!snap.exists) return null;
    return AppUser.fromFirestore(snap);
  }

  /// Merges [data] into the user document for [uid]. Creates the doc if absent.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    _assertValidUid(uid);
    await usersCollection.doc(uid).set(data, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Lessons — subcollection: users/{uid}/lessons
  // ---------------------------------------------------------------------------

  /// Streams all lessons for [uid], ordered newest first.
  ///
  /// Uses server-side ordering to avoid client-side sort overhead.
  /// No pagination limit is applied because many screens (progress, logbook,
  /// exercise history) require the full set for client-side aggregation.
  /// PPL students generate at most ~100 lessons; with Firestore offline
  /// persistence, repeat reads are served from cache at no additional cost.
  Stream<List<Lesson>> userLessonsStream(String uid) {
    _assertValidUid(uid);
    return lessonsCollection(uid)
        .snapshots()
        .map((qs) {
          final items = <Lesson>[];
          for (final doc in qs.docs) {
            try {
              items.add(Lesson.fromFirestore(doc));
            } catch (e) {
              debugPrint('Skipping malformed document ${doc.id}: $e');
            }
          }
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  /// Streams the [count] most recent lessons for [uid], newest first.
  ///
  /// Uses server-side limit() to avoid downloading the entire collection.
  Stream<List<Lesson>> recentLessonsStream(String uid, {int count = 5}) {
    _assertValidUid(uid);
    return lessonsCollection(uid)
        .orderBy('created_at', descending: true)
        .limit(count)
        .snapshots()
        .map((qs) {
          final items = <Lesson>[];
          for (final doc in qs.docs) {
            try {
              items.add(Lesson.fromFirestore(doc));
            } catch (e) {
              debugPrint('Skipping malformed document ${doc.id}: $e');
            }
          }
          return items;
        });
  }

  /// One-shot fetch of a single lesson by its document ID.
  Future<Lesson?> getLesson(String uid, String lessonId) async {
    _assertValidUid(uid);
    final snap = await lessonsCollection(uid).doc(lessonId).get();
    if (!snap.exists) return null;
    return Lesson.fromFirestore(snap);
  }

  /// Creates a new lesson document. Returns the auto-generated Firestore doc ID.
  /// No userId field is written to the document — ownership is implicit in path.
  Future<String> createLesson(String uid, Lesson lesson) async {
    _assertValidUid(uid);
    final data = lesson.toFirestore();
    // Do not write userId field — ownership is encoded in the path.
    data.remove('user_id');
    final ref = await lessonsCollection(uid).add(data);
    return ref.id;
  }

  /// Merges [data] into the lesson document [lessonId] for [uid].
  Future<void> updateLesson(
    String uid,
    String lessonId,
    Map<String, dynamic> data,
  ) async {
    _assertValidUid(uid);
    await lessonsCollection(uid).doc(lessonId).update(data);
  }

  /// Permanently deletes the lesson document [lessonId] from Firestore.
  Future<void> deleteLesson(String uid, String lessonId) async {
    _assertValidUid(uid);
    await lessonsCollection(uid).doc(lessonId).delete();
  }

  // ---------------------------------------------------------------------------
  // User Exercises — subcollection: users/{uid}/exercises
  // ---------------------------------------------------------------------------

  /// Streams all UserExercise records for [uid].
  Stream<List<UserExercise>> userExercisesStream(String uid) {
    _assertValidUid(uid);
    return exercisesCollection(uid)
        .snapshots()
        .map((qs) {
          final items = <UserExercise>[];
          for (final doc in qs.docs) {
            try {
              items.add(UserExercise.fromFirestore(doc));
            } catch (e) {
              debugPrint('Skipping malformed document ${doc.id}: $e');
            }
          }
          return items;
        });
  }

  /// One-shot fetch of a single UserExercise. Returns null if not found.
  Future<UserExercise?> getUserExercise(
    String uid,
    String exerciseId, {
    String? subExerciseId,
  }) async {
    _assertValidUid(uid);
    final docId = _exerciseDocId(exerciseId, subExerciseId: subExerciseId);
    final snap = await exercisesCollection(uid).doc(docId).get();
    if (!snap.exists) return null;
    return UserExercise.fromFirestore(snap);
  }

  /// Merges [data] into the UserExercise document identified by [docId].
  /// Use this for partial field updates (e.g. debrief notes) where you do not
  /// want to clobber unrelated fields.
  Future<void> updateUserExerciseFields(
    String uid,
    String docId,
    Map<String, dynamic> data,
  ) async {
    _assertValidUid(uid);
    await exercisesCollection(uid).doc(docId).set(data, SetOptions(merge: true));
  }

  /// Creates or fully replaces the UserExercise document.
  /// Uses a deterministic document ID so concurrent writes are idempotent.
  /// No userId field is written — ownership is implicit in the path.
  Future<void> upsertUserExercise(String uid, UserExercise ue) async {
    _assertValidUid(uid);
    final docId = _exerciseDocId(ue.exerciseId, subExerciseId: ue.subExercise);
    final data = ue.toFirestore();
    // Do not write userId field — ownership is encoded in the path.
    data.remove('user_id');
    await exercisesCollection(uid).doc(docId).set(data, SetOptions(merge: true));
  }

  // ---------------------------------------------------------------------------
  // Account Deletion
  // ---------------------------------------------------------------------------

  /// Permanently deletes all user data and the Firebase Auth account by
  /// calling the `deleteUserAccount` Cloud Function. The Cloud Function uses
  /// the Admin SDK, which bypasses Firestore security rules that block
  /// client-side deletion of subcollections, share_links, etc.
  ///
  /// The Cloud Function deletes:
  ///   - The `users/{uid}/lessons` subcollection
  ///   - The `users/{uid}/exercises` subcollection
  ///   - All `share_links` where user_id == uid
  ///   - The `users/{uid}` profile document
  ///   - The Firebase Auth account
  ///
  /// The caller does NOT need to delete the Auth account separately —
  /// the Cloud Function handles it.
  Future<void> deleteAllUserData(String uid) async {
    _assertValidUid(uid);

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable('deleteUserAccount');
      await callable.call();
    } catch (e, stack) {
      FirebaseCrashlytics.instance.recordError(
        e,
        stack,
        reason: 'deleteUserAccount Cloud Function failed',
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Cache Invalidation
  // ---------------------------------------------------------------------------

  /// Key used in SharedPreferences to store the last-seen content_version.
  static const _contentVersionKey = 'content_version';

  /// Checks the content_version of the first exercise_content doc in Firestore
  /// against the locally stored version. If they differ, clears the Hive
  /// exercise content cache so that providers re-fetch fresh data.
  ///
  /// Call this once on app startup (after HiveService.init).
  /// Fails silently on network errors — the app will use stale cache instead.
  Future<void> checkAndInvalidateCache() async {
    try {
      // Fetch one exercise_content doc to get the current content_version.
      final snapshot = await exerciseContentCollection.limit(1).get();
      if (snapshot.docs.isEmpty) return;

      final remoteVersion =
          (snapshot.docs.first.data()['content_version'] as int?) ?? 1;

      final prefs = await SharedPreferences.getInstance();
      final localVersion = prefs.getInt(_contentVersionKey) ?? 0;

      if (localVersion != remoteVersion) {
        // Content has been updated — clear the Hive cache.
        await HiveService().clearExerciseCache();
        await prefs.setInt(_contentVersionKey, remoteVersion);
      }
    } catch (_) {
      // Network or Firestore error — continue with existing cache.
    }
  }

  // ---------------------------------------------------------------------------
  // Exercise Content
  // ---------------------------------------------------------------------------

  /// Fetches exercise content from Firestore. Returns null if the doc is absent.
  Future<ExerciseContent?> getExerciseContent(
    String exerciseId, {
    String? subExerciseId,
  }) async {
    final docId =
        _exerciseContentDocId(exerciseId, subExerciseId: subExerciseId);
    final snap = await exerciseContentCollection.doc(docId).get();
    if (!snap.exists) return null;
    return ExerciseContent.fromFirestore(snap);
  }

  // ---------------------------------------------------------------------------
  // Quiz Questions
  // ---------------------------------------------------------------------------

  /// Fetches up to 10 quiz questions for [exerciseId], shuffled randomly.
  /// Pass [subExerciseId] for sub-exercises (e.g. '10a').
  Future<List<QuizQuestion>> getQuizQuestions(
    String exerciseId, {
    String? subExerciseId,
  }) async {
    Query<Map<String, dynamic>> query =
        quizQuestionsCollection.where('exercise_id', isEqualTo: exerciseId);

    if (subExerciseId != null) {
      query = query.where('sub_exercise', isEqualTo: subExerciseId);
    } else {
      // When no sub-exercise is requested, exclude questions that belong to
      // sub-exercises (i.e. sub_exercise field is absent / null).
      query = query.where('sub_exercise', isNull: true);
    }

    final qs = await query.get();
    final questions = <QuizQuestion>[];
    for (final doc in qs.docs) {
      try {
        questions.add(QuizQuestion.fromFirestore(doc));
      } catch (e) {
        debugPrint('Skipping malformed document ${doc.id}: $e');
      }
    }

    // Shuffle and cap at 10.
    questions.shuffle();
    return questions.take(10).toList();
  }

  // ---------------------------------------------------------------------------
  // Flashcards
  // ---------------------------------------------------------------------------

  /// Fetches all flashcards for [exerciseId].
  Future<List<Flashcard>> getFlashcards(String exerciseId) async {
    final qs = await flashcardsCollection
        .where('exercise_id', isEqualTo: exerciseId)
        .get();
    final cards = <Flashcard>[];
    for (final doc in qs.docs) {
      try {
        cards.add(Flashcard.fromFirestore(doc));
      } catch (e) {
        debugPrint('Skipping malformed document ${doc.id}: $e');
      }
    }
    return cards;
  }

  /// Cached daily question result — avoids re-fetching within the same session.
  /// Keyed by seed string (date).
  final Map<String, QuizQuestion?> _dailyQuestionCache = {};

  static const String _dailyQuestionPrefPrefix = 'daily_q_';

  /// Fetches a random single quiz question, deterministic for a given [seed]
  /// (typically a date string like "2026-03-22") so the same question is
  /// always shown within the same day.
  ///
  /// Performance: On the first call of a given day, fetches the full
  /// quiz_questions collection (one-time cost), picks a question by seed hash,
  /// and persists the doc ID in SharedPreferences. On subsequent cold starts
  /// for the same date, does a single doc get() — ~200× fewer reads.
  Future<QuizQuestion?> getDailyQuestion(String seed) async {
    // 1. In-memory cache — fastest path, no I/O.
    if (_dailyQuestionCache.containsKey(seed)) {
      return _dailyQuestionCache[seed];
    }

    // 2. SharedPreferences cache — survives app restarts within the same day.
    final prefs = await SharedPreferences.getInstance();
    final cachedDocId = prefs.getString('$_dailyQuestionPrefPrefix$seed');
    if (cachedDocId != null) {
      final snap = await quizQuestionsCollection.doc(cachedDocId).get();
      if (snap.exists) {
        final question = QuizQuestion.fromFirestore(snap);
        _dailyQuestionCache[seed] = question;
        return question;
      }
      // Cached doc ID is stale (doc deleted) — fall through to full scan.
    }

    // 3. Full scan — only runs once per day per device.
    final qs = await quizQuestionsCollection.get();
    if (qs.docs.isEmpty) {
      _dailyQuestionCache[seed] = null;
      return null;
    }

    // Use the seed's hash to pick a stable index within the collection.
    final index = seed.hashCode.abs() % qs.docs.length;
    final doc = qs.docs[index];
    final question = QuizQuestion.fromFirestore(doc);

    // Persist today's doc ID so tomorrow's cold start skips the full scan.
    await prefs.setString('$_dailyQuestionPrefPrefix$seed', doc.id);

    _dailyQuestionCache[seed] = question;
    return question;
  }

  // ---------------------------------------------------------------------------
  // Share Links
  // ---------------------------------------------------------------------------

  /// Creates a share link document for [userId] with the given [token].
  /// The link expires 30 days from creation and is active by default.
  Future<void> createShareLink(String userId, String token) async {
    _assertValidUid(userId);
    final now = DateTime.now();
    await shareLinksCollection.doc(token).set({
      'user_id': userId,
      'share_token': token,
      'created_at': Timestamp.fromDate(now),
      'expires_at': Timestamp.fromDate(now.add(const Duration(days: 30))),
      'is_active': true,
    });
  }

  /// Returns the most recent active share link for [userId], or null if none.
  Future<Map<String, dynamic>?> getActiveShareLink(String userId) async {
    _assertValidUid(userId);
    final now = Timestamp.fromDate(DateTime.now());
    final qs = await shareLinksCollection
        .where('user_id', isEqualTo: userId)
        .where('is_active', isEqualTo: true)
        .where('expires_at', isGreaterThan: now)
        .orderBy('expires_at', descending: true)
        .limit(1)
        .get();
    if (qs.docs.isEmpty) return null;
    return qs.docs.first.data();
  }

  /// Revokes the share link with the given [shareToken] by setting isActive
  /// to false.
  Future<void> revokeShareLink(String shareToken) async {
    await shareLinksCollection.doc(shareToken).update({'is_active': false});
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Singleton [FirestoreService] instance.
final firestoreServiceProvider = Provider<FirestoreService>(
  (_) => FirestoreService(),
);

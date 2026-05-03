// User profile model — maps to the Firestore `users/{uid}` document.
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the authenticated user's profile stored in Firestore.
class AppUser {
  final String uid;
  final String displayName;
  final String email;
  final double hoursFlown;
  final String aircraftType;
  final String flightSchool;
  final String airfieldIcao;
  final String subscriptionStatus; // free | pro | premium | lifetime
  final bool hasPurchased;
  final bool grantedAccess;
  final bool disclaimerAcknowledged;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? profilePhotoUrl;
  final DateTime? purchaseDate;
  final int currentExerciseNumber; // Where in training (1-19), determines free window

  /// Suggested exercise number from the onboarding quiz (1-19). Null if the
  /// quiz has not been completed yet.
  final int? suggestedExerciseNumber;

  /// Timestamp of the last submitted debrief, used to drive the home nudge card.
  final DateTime? lastDebriefAt;

  /// Per-category notification preferences, e.g. {'lesson_reminders': true}.
  final Map<String, bool> notificationPreferences;

  /// Number of consecutive days the user has opened the app.
  final int studyStreak;

  /// The date on which the user was last seen active, used to compute the streak.
  final DateTime? lastActiveDate;

  /// The date on which the user is scheduled to sit their skills test.
  final DateTime? skillsTestDate;

  const AppUser({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.hoursFlown,
    required this.aircraftType,
    required this.flightSchool,
    required this.airfieldIcao,
    required this.subscriptionStatus,
    this.hasPurchased = false,
    this.grantedAccess = false,
    required this.disclaimerAcknowledged,
    required this.createdAt,
    this.updatedAt,
    this.profilePhotoUrl,
    this.purchaseDate,
    this.currentExerciseNumber = 1,
    this.suggestedExerciseNumber,
    this.notificationPreferences = const {},
    this.lastDebriefAt,
    this.studyStreak = 0,
    this.lastActiveDate,
    this.skillsTestDate,
  });

  /// Constructs an [AppUser] from a Firestore document snapshot.
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      displayName: data['display_name'] ?? '',
      email: data['email'] ?? '',
      hoursFlown: (data['hours_flown'] ?? 0).toDouble(),
      aircraftType: data['aircraft_type'] ?? '',
      flightSchool: data['flight_school'] ?? '',
      airfieldIcao: data['airfield_icao'] ?? '',
      subscriptionStatus: data['subscription_status'] ?? 'free',
      hasPurchased: data['has_purchased'] ?? false,
      grantedAccess: data['granted_access'] ?? false,
      disclaimerAcknowledged: data['disclaimer_acknowledged'] ?? false,
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate(),
      profilePhotoUrl: _sanitisePhotoUrl(data['profile_photo_url']),
      purchaseDate: (data['purchase_date'] as Timestamp?)?.toDate(),
      currentExerciseNumber:
          (data['current_exercise_number'] ?? 1).toInt().clamp(1, 19),
      suggestedExerciseNumber: data['suggested_exercise_number'] != null
          ? (data['suggested_exercise_number'] as num).toInt().clamp(1, 19)
          : null,
      notificationPreferences: _parseNotificationPreferences(
        data['notification_preferences'],
      ),
      lastDebriefAt: (data['last_debrief_at'] as Timestamp?)?.toDate(),
      studyStreak: (data['study_streak'] ?? 0).toInt(),
      lastActiveDate: (data['last_active_date'] as Timestamp?)?.toDate(),
      skillsTestDate: (data['skills_test_date'] as Timestamp?)?.toDate(),
    );
  }

  /// Rejects URLs that don't start with https:// to prevent XSS via data:/javascript: URIs.
  static String? _sanitisePhotoUrl(dynamic raw) {
    if (raw == null) return null;
    final url = raw as String;
    return url.startsWith('https://') ? url : null;
  }

  static Map<String, bool> _parseNotificationPreferences(dynamic raw) {
    if (raw == null) return {};
    if (raw is! Map) return {};
    return Map<String, bool>.from(
      (raw as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, v == true),
      ),
    );
  }

  /// True when the user has purchased the full-access Pro upgrade.
  /// Accepts any of the valid paid status values: 'pro', 'premium', 'lifetime'.
  bool get isPremium =>
      hasPurchased ||
      grantedAccess ||
      subscriptionStatus == 'pro' ||
      subscriptionStatus == 'premium' ||
      subscriptionStatus == 'lifetime';

  /// Extracts the numeric exercise number from a composite ID.
  /// e.g. 'ex_10_10a' → 10, 'ex_05' → 5, 'ex_18_18b' → 18.
  static int exerciseNumberFromId(String compositeExerciseId) {
    final parts = compositeExerciseId.split('_');
    if (parts.length >= 2) {
      return int.tryParse(parts[1]) ?? 1;
    }
    return 1;
  }

  /// The lowest exercise number in the user's free window (clamped to 1).
  int get freeWindowStart => math.max(1, currentExerciseNumber - 2);

  /// The highest exercise number in the user's free window (clamped to 19).
  int get freeWindowEnd => math.min(19, currentExerciseNumber + 2);

  /// Returns true if the given exercise number falls within the free window.
  bool isExerciseInFreeWindow(int exerciseNumber) {
    return exerciseNumber >= freeWindowStart && exerciseNumber <= freeWindowEnd;
  }

  /// Returns true if the user can access the given exercise.
  /// Free window = currentExerciseNumber ± 2 (5 exercises).
  /// Premium users can access everything.
  bool canAccessExercise(String compositeExerciseId) {
    final exNum = exerciseNumberFromId(compositeExerciseId);
    if (isExerciseInFreeWindow(exNum)) return true;
    return isPremium;
  }

  /// Serialises this user to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'display_name': displayName,
    'email': email,
    'hours_flown': hoursFlown,
    'aircraft_type': aircraftType,
    'flight_school': flightSchool,
    'airfield_icao': airfieldIcao,
    'subscription_status': subscriptionStatus,
    'has_purchased': hasPurchased,
    'granted_access': grantedAccess,
    'disclaimer_acknowledged': disclaimerAcknowledged,
    'created_at': Timestamp.fromDate(createdAt),
    if (updatedAt != null) 'updated_at': Timestamp.fromDate(updatedAt!),
    if (profilePhotoUrl != null) 'profile_photo_url': profilePhotoUrl,
    if (purchaseDate != null) 'purchase_date': Timestamp.fromDate(purchaseDate!),
    'current_exercise_number': currentExerciseNumber,
    if (suggestedExerciseNumber != null)
      'suggested_exercise_number': suggestedExerciseNumber,
    if (notificationPreferences.isNotEmpty)
      'notification_preferences': notificationPreferences,
    if (lastDebriefAt != null)
      'last_debrief_at': Timestamp.fromDate(lastDebriefAt!),
    'study_streak': studyStreak,
    if (lastActiveDate != null)
      'last_active_date': Timestamp.fromDate(lastActiveDate!),
    if (skillsTestDate != null) 'skills_test_date': Timestamp.fromDate(skillsTestDate!),
  };

  /// Returns a copy with the given fields replaced.
  AppUser copyWith({
    String? displayName,
    String? email,
    double? hoursFlown,
    String? aircraftType,
    String? flightSchool,
    String? airfieldIcao,
    String? subscriptionStatus,
    bool? hasPurchased,
    bool? grantedAccess,
    bool? disclaimerAcknowledged,
    DateTime? updatedAt,
    String? profilePhotoUrl,
    DateTime? purchaseDate,
    int? currentExerciseNumber,
    int? suggestedExerciseNumber,
    Map<String, bool>? notificationPreferences,
    DateTime? lastDebriefAt,
    int? studyStreak,
    DateTime? lastActiveDate,
    DateTime? skillsTestDate,
  }) {
    return AppUser(
      uid: uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      hoursFlown: hoursFlown ?? this.hoursFlown,
      aircraftType: aircraftType ?? this.aircraftType,
      flightSchool: flightSchool ?? this.flightSchool,
      airfieldIcao: airfieldIcao ?? this.airfieldIcao,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      hasPurchased: hasPurchased ?? this.hasPurchased,
      grantedAccess: grantedAccess ?? this.grantedAccess,
      disclaimerAcknowledged:
          disclaimerAcknowledged ?? this.disclaimerAcknowledged,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      currentExerciseNumber:
          currentExerciseNumber ?? this.currentExerciseNumber,
      suggestedExerciseNumber:
          suggestedExerciseNumber ?? this.suggestedExerciseNumber,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
      lastDebriefAt: lastDebriefAt ?? this.lastDebriefAt,
      studyStreak: studyStreak ?? this.studyStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      skillsTestDate: skillsTestDate ?? this.skillsTestDate,
    );
  }

  /// True when the skills test is within the next 21 days and hasn't passed yet.
  bool get isInTestPrepWindow {
    if (skillsTestDate == null) return false;
    final now = DateTime.now();
    if (skillsTestDate!.isBefore(now)) return false;
    return skillsTestDate!.difference(now).inDays <= 21;
  }
}

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
  final String role; // 'student' | 'instructor'
  final String? instructorQualification;
  final String? inviteCode; // 6-char code for instructors
  final int currentExerciseNumber; // Where in training (1-19), determines free window

  /// Per-category notification preferences, e.g. {'lesson_reminders': true}.
  final Map<String, bool> notificationPreferences;

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
    this.role = 'student',
    this.instructorQualification,
    this.inviteCode,
    this.currentExerciseNumber = 1,
    this.notificationPreferences = const {},
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
      role: data['user_role'] ?? 'student',
      instructorQualification: data['instructor_qualification'],
      inviteCode: data['invite_code'],
      currentExerciseNumber:
          (data['current_exercise_number'] ?? 1).toInt().clamp(1, 19),
      notificationPreferences: _parseNotificationPreferences(
        data['notification_preferences'],
      ),
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

  /// True when the user is an instructor.
  bool get isInstructor => role == 'instructor';

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
    'user_role': role,
    if (instructorQualification != null)
      'instructor_qualification': instructorQualification,
    if (inviteCode != null) 'invite_code': inviteCode,
    'current_exercise_number': currentExerciseNumber,
    if (notificationPreferences.isNotEmpty)
      'notification_preferences': notificationPreferences,
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
    String? role,
    String? instructorQualification,
    String? inviteCode,
    int? currentExerciseNumber,
    Map<String, bool>? notificationPreferences,
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
      role: role ?? this.role,
      instructorQualification:
          instructorQualification ?? this.instructorQualification,
      inviteCode: inviteCode ?? this.inviteCode,
      currentExerciseNumber:
          currentExerciseNumber ?? this.currentExerciseNumber,
      notificationPreferences:
          notificationPreferences ?? this.notificationPreferences,
    );
  }
}

// Application-wide constants — business rules and exercise metadata.
// RevenueCat SDK keys are NOT stored here — they come from --dart-define at
// compile time and are read by lib/shared/services/subscription_service.dart.

/// Application-wide constants — business rules and exercise metadata.
class AppConstants {
  // Subscription — one-time lifetime purchase (£49)
  static const String entitlementId = 'pro';
  static const double premiumPriceGbp = 49.0;

  // Free tier — personalised window based on where the student is in training.
  // Students get their current exercise ± 2 either side (5 exercises total).
  // Use AppUser.canAccessExercise() for access checks.

  /// Returns true if the given exercise is within the free window for the
  /// specified [currentExerciseNumber] (1-19). The free window spans
  /// currentExerciseNumber - 2 to currentExerciseNumber + 2, clamped to 1-19.
  static bool isFreeExercise(String compositeExerciseId, {int currentExerciseNumber = 1}) {
    final parts = compositeExerciseId.split('_');
    final exNum = parts.length >= 2 ? (int.tryParse(parts[1]) ?? 1) : 1;
    final windowStart = (currentExerciseNumber - 2).clamp(1, 19);
    final windowEnd = (currentExerciseNumber + 2).clamp(1, 19);
    return exNum >= windowStart && exNum <= windowEnd;
  }

  // Business rules
  static const int quizPassThreshold = 75; // percent — CAA standard
  static const int quizConsecutiveFailPrompt = 3;
  static const int minQuizQuestions = 8;
  static const int maxQuizQuestions = 10;

  // Quiet hours (no notifications)
  static const int quietHourStart = 22; // 10pm
  static const int quietHourEnd = 8;    // 8am

  // Spaced repetition intervals (days)
  static const List<int> spacedRepIntervals = [1, 3, 7, 14];

  // Aircraft types — common UK PPL(A) training aircraft.
  // Keys must match tips fields in Firestore exercise_content documents.
  static const Map<String, String> aircraftTypes = {
    'cessna_152': 'Cessna 152',
    'cessna_172': 'Cessna 172',
    'pa28': 'Piper PA-28 Warrior',
    'pa28_181': 'Piper PA-28-181 Archer',
    'pa38': 'Piper PA-38 Tomahawk',
    'da40': 'Diamond DA40',
    'da20': 'Diamond DA20 Katana',
    'robin_dr400': 'Robin DR400',
    'grob_g115': 'Grob G115 Tutor',
    'tecnam_p2002': 'Tecnam P2002 Sierra',
  };

  // Exercise short names — "Exercise 1"
  static const Map<String, String> exerciseNames = {
    'ex_01': 'Exercise 1',
    'ex_02': 'Exercise 2',
    'ex_03': 'Exercise 3',
    'ex_04': 'Exercise 4',
    'ex_05': 'Exercise 5',
    'ex_06': 'Exercise 6',
    'ex_07': 'Exercise 7',
    'ex_08': 'Exercise 8',
    'ex_09': 'Exercise 9',
    'ex_10': 'Exercise 10',
    'ex_10_10a': 'Exercise 10A',
    'ex_10_10b': 'Exercise 10B',
    'ex_11': 'Exercise 11',
    'ex_12': 'Exercise 12',
    'ex_13': 'Exercise 13',
    'ex_14': 'Exercise 14',
    'ex_15': 'Exercise 15',
    'ex_16': 'Exercise 16',
    'ex_17': 'Exercise 17',
    'ex_18': 'Exercise 18',
    'ex_18_18a': 'Exercise 18A',
    'ex_18_18b': 'Exercise 18B',
    'ex_18_18c': 'Exercise 18C',
    'ex_19': 'Exercise 19',
  };

  // Full CAA exercise titles
  static const Map<String, String> exerciseTitles = {
    'ex_01': 'Familiarisation with the Aeroplane',
    'ex_02': 'Preparation for and Action after Flight',
    'ex_03': 'Air Experience',
    'ex_04': 'Effects of Controls',
    'ex_05': 'Taxiing',
    'ex_06': 'Straight and Level Flight',
    'ex_07': 'Climbing',
    'ex_08': 'Descending',
    'ex_09': 'Turning',
    'ex_10_10a': 'Slow Flight',
    'ex_10_10b': 'Stalling',
    'ex_11': 'Spin Awareness and Recovery',
    'ex_12': 'Take-off and Climb to Downwind',
    'ex_13': 'Circuit, Approach and Landing',
    'ex_14': 'First Solo',
    'ex_15': 'Advanced Turning',
    'ex_16': 'Forced Landing Without Power',
    'ex_17': 'Precautionary Landing',
    'ex_18_18a': 'Navigation',
    'ex_18_18b': 'Navigation at Lower Levels',
    'ex_18_18c': 'Radio Navigation',
    'ex_19': 'Night Flying',
  };

  // All composite exercise IDs in syllabus order
  static const List<String> allExerciseIds = [
    'ex_01', 'ex_02', 'ex_03', 'ex_04', 'ex_05',
    'ex_06', 'ex_07', 'ex_08', 'ex_09',
    'ex_10_10a', 'ex_10_10b',
    'ex_11', 'ex_12', 'ex_13', 'ex_14', 'ex_15',
    'ex_16', 'ex_17',
    'ex_18_18a', 'ex_18_18b', 'ex_18_18c',
    'ex_19',
  ];

  // Flight duration limits
  static const int maxFlightHours = 8;
  static const int maxFlightMinutes = 59;

  // Check-in reminder delay (minutes after lesson)
  static const int checkinReminderDelayMinutes = 90;
}

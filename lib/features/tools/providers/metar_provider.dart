// METAR training state — manages ICAO selection, live fetch, question
// progression, answer grading, session scoring, and daily free-tier gating.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flight_path/shared/providers/app_user_provider.dart';
import 'package:flight_path/shared/providers/subscription_provider.dart';
import 'package:flight_path/shared/services/avwx_service.dart';

// ---------------------------------------------------------------------------
// Shared preferences keys (UID-scoped to prevent cross-user leakage)
// ---------------------------------------------------------------------------

String _kDailyCountKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'metar_daily_count_$uid';
}

String _kDailyDateKey() {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
  return 'metar_daily_date_$uid';
}

// ---------------------------------------------------------------------------
// AvwxService provider
// ---------------------------------------------------------------------------

/// Singleton [AvwxService] instance.
final avwxServiceProvider = Provider<AvwxService>((_) => AvwxService());

// ---------------------------------------------------------------------------
// METAR question model
// ---------------------------------------------------------------------------

/// The five fixed questions asked per METAR session.
enum MetarQuestionId {
  wind,
  visibility,
  cloudBase,
  qnh,
  vfrLegal,
}

/// A single METAR question definition.
class MetarQuestion {
  final MetarQuestionId id;
  final String prompt;

  /// Choices for multiple-choice questions. Empty = free-text input.
  final List<String> choices;

  const MetarQuestion({
    required this.id,
    required this.prompt,
    this.choices = const [],
  });
}

/// The fixed set of five questions shown for every METAR.
const List<MetarQuestion> kMetarQuestions = [
  MetarQuestion(
    id: MetarQuestionId.wind,
    prompt: 'What is the wind direction and speed?',
  ),
  MetarQuestion(
    id: MetarQuestionId.visibility,
    prompt: 'What is the visibility?',
  ),
  MetarQuestion(
    id: MetarQuestionId.cloudBase,
    prompt: 'What is the lowest cloud base?',
    choices: ['SKC', 'CAVOK', 'Enter value'],
  ),
  MetarQuestion(
    id: MetarQuestionId.qnh,
    prompt: 'What is the QNH?',
  ),
  MetarQuestion(
    id: MetarQuestionId.vfrLegal,
    prompt:
        'Is this weather VFR legal for a student pilot?\n'
        '(VMC minima: 1500 m vis, clear of cloud)',
    choices: ['Yes', 'No', 'Marginal'],
  ),
];

// ---------------------------------------------------------------------------
// Answer result
// ---------------------------------------------------------------------------

/// Result of grading a single student answer against the decoded METAR.
class MetarAnswerResult {
  final MetarQuestionId questionId;
  final String studentAnswer;
  final String correctAnswer;
  final String explanation;
  final bool isCorrect;

  const MetarAnswerResult({
    required this.questionId,
    required this.studentAnswer,
    required this.correctAnswer,
    required this.explanation,
    required this.isCorrect,
  });
}

// ---------------------------------------------------------------------------
// Session state
// ---------------------------------------------------------------------------

/// Immutable snapshot of the METAR training session.
class MetarSessionState {
  /// Currently selected ICAO code.
  final String icao;

  /// Raw METAR string as returned by AVWX. Null while loading or on error.
  final String? rawMetar;

  /// True while a network fetch is in progress.
  final bool isLoading;

  /// True when the fetch completed but returned null (network/HTTP error).
  final bool fetchError;

  /// True when AVWX confirmed the station doesn't publish live METARs (204/404).
  final bool noDataForStation;

  /// Index of the currently active question (0–4).
  final int questionIndex;

  /// Answers submitted so far in this session, in question order.
  final List<MetarAnswerResult> answers;

  /// True when the session (all 5 questions) is complete.
  final bool sessionComplete;

  /// Number of METAR sessions used today (free tier limit: 5).
  final int dailySessionCount;

  /// True when the user has reached the free-tier daily limit and is not
  /// premium. The screen should show the paywall at this point.
  final bool paywallRequired;

  const MetarSessionState({
    required this.icao,
    this.rawMetar,
    this.isLoading = false,
    this.fetchError = false,
    this.noDataForStation = false,
    this.questionIndex = 0,
    this.answers = const [],
    this.sessionComplete = false,
    this.dailySessionCount = 0,
    this.paywallRequired = false,
  });

  int get correctCount => answers.where((a) => a.isCorrect).length;
  int get totalAnswered => answers.length;

  MetarSessionState copyWith({
    String? icao,
    String? rawMetar,
    bool? isLoading,
    bool? fetchError,
    bool? noDataForStation,
    int? questionIndex,
    List<MetarAnswerResult>? answers,
    bool? sessionComplete,
    int? dailySessionCount,
    bool? paywallRequired,
    bool clearMetar = false,
  }) {
    return MetarSessionState(
      icao: icao ?? this.icao,
      rawMetar: clearMetar ? null : (rawMetar ?? this.rawMetar),
      isLoading: isLoading ?? this.isLoading,
      fetchError: fetchError ?? this.fetchError,
      noDataForStation: noDataForStation ?? this.noDataForStation,
      questionIndex: questionIndex ?? this.questionIndex,
      answers: answers ?? this.answers,
      sessionComplete: sessionComplete ?? this.sessionComplete,
      dailySessionCount: dailySessionCount ?? this.dailySessionCount,
      paywallRequired: paywallRequired ?? this.paywallRequired,
    );
  }
}

// ---------------------------------------------------------------------------
// StateNotifier
// ---------------------------------------------------------------------------

class MetarNotifier extends StateNotifier<MetarSessionState> {
  final AvwxService _avwx;
  final Ref _ref;

  MetarNotifier(this._avwx, this._ref, {String initialIcao = 'EGTC'})
      : super(MetarSessionState(icao: initialIcao)) {
    _loadDailyCount();
  }

  // ── Daily usage ────────────────────────────────────────────────────────────

  Future<void> _loadDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDate = prefs.getString(_kDailyDateKey()) ?? '';
    final today = _todayString();
    if (storedDate != today) {
      // New day — reset counter.
      await prefs.setInt(_kDailyCountKey(), 0);
      await prefs.setString(_kDailyDateKey(), today);
      state = state.copyWith(dailySessionCount: 0);
    } else {
      final count = prefs.getInt(_kDailyCountKey()) ?? 0;
      state = state.copyWith(dailySessionCount: count);
    }
  }

  Future<void> _incrementDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayString();
    await prefs.setString(_kDailyDateKey(), today);
    final newCount = (prefs.getInt(_kDailyCountKey()) ?? 0) + 1;
    await prefs.setInt(_kDailyCountKey(), newCount);
    state = state.copyWith(dailySessionCount: newCount);
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ── ICAO selection ─────────────────────────────────────────────────────────

  /// Changes the active airfield and immediately fetches a fresh METAR.
  Future<void> selectIcao(String icao) async {
    state = state.copyWith(
      icao: icao,
      clearMetar: true,
      questionIndex: 0,
      answers: const [],
      sessionComplete: false,
      fetchError: false,
      noDataForStation: false,
      paywallRequired: false,
    );
    await fetchMetar();
  }

  // ── Fetch ──────────────────────────────────────────────────────────────────

  /// Fetches a live METAR for the current ICAO.
  /// Handles paywall gate: if free-tier limit reached and user is not premium,
  /// sets [paywallRequired] = true without fetching.
  Future<void> fetchMetar() async {
    // Refresh daily count first so midnight rollovers are handled correctly.
    await _loadDailyCount();
    // Check free tier before counting the session.
    if (state.dailySessionCount >= 3) {
      // Use the comprehensive check: AppUser.isPremium covers granted_access +
      // subscription_status, falling back to RevenueCat. SubscriptionService
      // alone misses the granted_access path.
      final premium = await _ref.read(premiumStatusProvider.future);
      if (!premium) {
        state = state.copyWith(paywallRequired: true);
        return;
      }
    }

    state = state.copyWith(
      isLoading: true,
      clearMetar: true,
      fetchError: false,
      noDataForStation: false,
      questionIndex: 0,
      answers: const [],
      sessionComplete: false,
      paywallRequired: false,
    );

    String? raw;
    bool fetchError = false;
    bool noDataForStation = false;

    try {
      raw = await _avwx.fetchMetar(state.icao);
      if (raw == null) fetchError = true;
    } on NoMetarDataException {
      noDataForStation = true;
    } catch (e) {
      if (kDebugMode) debugPrint('MetarNotifier: unexpected error — $e');
      fetchError = true;
    }

    state = state.copyWith(
      isLoading: false,
      rawMetar: raw,
      fetchError: fetchError,
      noDataForStation: noDataForStation,
    );

  }

  // ── Answer submission ──────────────────────────────────────────────────────

  /// Grades [studentAnswer] for the current question and advances the state.
  ///
  /// Returns the [MetarAnswerResult] so the UI can display immediate feedback.
  MetarAnswerResult submitAnswer(String studentAnswer) {
    // Count on first answer — exits without answering don't use a session.
    if (state.answers.isEmpty) _incrementDailyCount();

    final question = kMetarQuestions[state.questionIndex];
    final metar = state.rawMetar ?? '';

    final result = _grade(question, studentAnswer, metar);
    final updatedAnswers = [...state.answers, result];
    final allAnswered = updatedAnswers.length == kMetarQuestions.length;

    state = state.copyWith(
      answers: updatedAnswers,
      questionIndex: allAnswered
          ? state.questionIndex
          : state.questionIndex + 1,
      sessionComplete: allAnswered,
    );

    return result;
  }

  /// Resets to a fresh session and fetches the next METAR for the same ICAO.
  Future<void> nextMetar() async {
    state = state.copyWith(
      clearMetar: true,
      questionIndex: 0,
      answers: const [],
      sessionComplete: false,
      fetchError: false,
      noDataForStation: false,
      paywallRequired: false,
    );
    await fetchMetar();
  }

  // ── Grading logic ──────────────────────────────────────────────────────────

  /// Parses the raw METAR string and grades [studentAnswer] for [question].
  ///
  /// Grading is intentionally lenient — we check whether the key value
  /// extracted from the METAR is present (case-insensitive) in the student's
  /// answer. Full mark-scheme accuracy is less important than instant feedback
  /// for learning purposes.
  MetarAnswerResult _grade(
    MetarQuestion question,
    String studentAnswer,
    String metar,
  ) {
    switch (question.id) {
      case MetarQuestionId.wind:
        return _gradeWind(studentAnswer, metar);
      case MetarQuestionId.visibility:
        return _gradeVisibility(studentAnswer, metar);
      case MetarQuestionId.cloudBase:
        return _gradeCloudBase(studentAnswer, metar);
      case MetarQuestionId.qnh:
        return _gradeQnh(studentAnswer, metar);
      case MetarQuestionId.vfrLegal:
        return _gradeVfrLegal(studentAnswer, metar);
    }
  }

  MetarAnswerResult _gradeWind(String student, String metar) {
    // Wind group: dddffKT or dddffGggKT, or VRB
    final windRe = RegExp(r'\b(VRB|\d{3})(\d{2,3})(G\d{2,3})?KT\b');
    final m = windRe.firstMatch(metar);
    if (m == null) {
      return MetarAnswerResult(
        questionId: MetarQuestionId.wind,
        studentAnswer: student,
        correctAnswer: 'Wind group not found in METAR',
        explanation:
            'Wind is encoded as dddffKT (e.g. 27015KT = 270° at 15 kt). '
            'VRB means variable direction.',
        isCorrect: false,
      );
    }
    final dir = m.group(1)!;
    final spd = m.group(2)!;
    final gust = m.group(3);
    final correct = gust != null
        ? '$dir° at ${spd}kt gusting ${gust.substring(1)}kt'
        : '$dir° at ${spd}kt';
    // Lenient: student must mention the speed digits.
    final isCorrect = student.toLowerCase().contains(spd.toLowerCase());
    return MetarAnswerResult(
      questionId: MetarQuestionId.wind,
      studentAnswer: student,
      correctAnswer: correct,
      explanation:
          'Wind group "${m.group(0)}" = $correct. '
          'Format: dddffKT where ddd is direction in degrees true '
          'and ff is speed in knots.',
      isCorrect: isCorrect,
    );
  }

  MetarAnswerResult _gradeVisibility(String student, String metar) {
    // Visibility: 4-digit metres or 9999, or CAVOK
    if (metar.contains('CAVOK')) {
      const correct = 'CAVOK (>10 km, no cloud below 5000 ft, no significant wx)';
      final isCorrect =
          student.toLowerCase().contains('cavok') ||
          student.contains('10') ||
          student.contains('9999');
      return MetarAnswerResult(
        questionId: MetarQuestionId.visibility,
        studentAnswer: student,
        correctAnswer: correct,
        explanation:
            'CAVOK = Ceiling And Visibility OK: visibility >10 km, no cloud '
            'below 5000 ft or MSA, and no significant weather.',
        isCorrect: isCorrect,
      );
    }
    final visRe = RegExp(r'\b(9999|\d{4})\b');
    final m = visRe.firstMatch(metar);
    if (m == null) {
      return MetarAnswerResult(
        questionId: MetarQuestionId.visibility,
        studentAnswer: student,
        correctAnswer: 'Visibility not found',
        explanation: 'Visibility is given in metres as a 4-digit group '
            '(e.g. 4000 = 4 km). 9999 means 10 km or more.',
        isCorrect: false,
      );
    }
    final vis = m.group(1)!;
    final visKm = vis == '9999'
        ? '10 km or more'
        : '${(int.parse(vis) / 1000).toStringAsFixed(1)} km';
    final correct = '$vis m ($visKm)';
    final isCorrect = student.contains(vis) ||
        (vis == '9999' && student.toLowerCase().contains('10'));
    return MetarAnswerResult(
      questionId: MetarQuestionId.visibility,
      studentAnswer: student,
      correctAnswer: correct,
      explanation:
          'Visibility "$vis" = $visKm. Encoded as a 4-digit metres value '
          'immediately after the wind group.',
      isCorrect: isCorrect,
    );
  }

  MetarAnswerResult _gradeCloudBase(String student, String metar) {
    // SKC / NSC / NCD = no cloud
    if (RegExp(r'\b(SKC|NSC|NCD)\b').hasMatch(metar)) {
      const correct = 'SKC / no cloud';
      final isCorrect = student.toLowerCase().contains('skc') ||
          student.toLowerCase().contains('clear') ||
          student.toLowerCase().contains('no cloud');
      return MetarAnswerResult(
        questionId: MetarQuestionId.cloudBase,
        studentAnswer: student,
        correctAnswer: correct,
        explanation:
            'SKC = Sky Clear (no cloud reported). NSC = No Significant Cloud.',
        isCorrect: isCorrect,
      );
    }
    if (metar.contains('CAVOK')) {
      const correct = 'CAVOK — no cloud below 5000 ft';
      final isCorrect = student.toLowerCase().contains('cavok') ||
          student.toLowerCase().contains('5000') ||
          student.toLowerCase().contains('clear');
      return MetarAnswerResult(
        questionId: MetarQuestionId.cloudBase,
        studentAnswer: student,
        correctAnswer: correct,
        explanation:
            'CAVOK includes no cloud below 5000 ft or MSA. '
            'Cloud base is therefore above 5000 ft.',
        isCorrect: isCorrect,
      );
    }
    // Find the lowest cloud layer: FEW/SCT/BKN/OVC + 3-digit hundreds of feet.
    final cloudRe = RegExp(r'\b(FEW|SCT|BKN|OVC)(\d{3})\b');
    final matches = cloudRe.allMatches(metar).toList();
    if (matches.isEmpty) {
      return MetarAnswerResult(
        questionId: MetarQuestionId.cloudBase,
        studentAnswer: student,
        correctAnswer: 'No cloud group found',
        explanation: 'Cloud groups: FEW/SCT/BKN/OVC followed by 3 digits '
            '(height in hundreds of feet, e.g. BKN018 = broken at 1800 ft).',
        isCorrect: false,
      );
    }
    // Lowest = smallest height value.
    matches.sort((a, b) =>
        int.parse(a.group(2)!).compareTo(int.parse(b.group(2)!)));
    final lowest = matches.first;
    final cover = lowest.group(1)!;
    final heightHundreds = int.parse(lowest.group(2)!);
    final heightFt = heightHundreds * 100;
    final coverFull = _cloudCoverFull(cover);
    final correct = '$cover${lowest.group(2)} = $coverFull at ${heightFt}ft';
    final isCorrect = student.contains(lowest.group(2)!) ||
        student.toLowerCase().contains(heightFt.toString());
    return MetarAnswerResult(
      questionId: MetarQuestionId.cloudBase,
      studentAnswer: student,
      correctAnswer: correct,
      explanation:
          '${lowest.group(0)} = $coverFull at ${heightFt}ft. '
          'Cloud groups are ordered lowest to highest. '
          'FEW = 1–2 oktas, SCT = 3–4, BKN = 5–7, OVC = 8 oktas (overcast).',
      isCorrect: isCorrect,
    );
  }

  MetarAnswerResult _gradeQnh(String student, String metar) {
    // QNH: Q followed by 4 digits, e.g. Q1013
    final qnhRe = RegExp(r'\bQ(\d{4})\b');
    final m = qnhRe.firstMatch(metar);
    if (m == null) {
      // Altimeter setting in inches (US/Canada): Axxxx
      final altRe = RegExp(r'\bA(\d{4})\b');
      final altM = altRe.firstMatch(metar);
      if (altM != null) {
        final inHg = '${altM.group(1)!.substring(0, 2)}.${altM.group(1)!.substring(2)} inHg';
        return MetarAnswerResult(
          questionId: MetarQuestionId.qnh,
          studentAnswer: student,
          correctAnswer: 'Altimeter: $inHg (non-UK format)',
          explanation:
              'Non-UK METAR uses altimeter setting in inches of mercury '
              '(prefix A). UK METARs use Q + 4-digit hPa value.',
          isCorrect: student.contains(altM.group(1)!.substring(0, 2)),
        );
      }
      return MetarAnswerResult(
        questionId: MetarQuestionId.qnh,
        studentAnswer: student,
        correctAnswer: 'QNH not found',
        explanation:
            'QNH is encoded as Q followed by 4 digits of hPa, '
            'e.g. Q1013 = 1013 hPa.',
        isCorrect: false,
      );
    }
    final hpa = m.group(1)!;
    final correct = '$hpa hPa';
    final isCorrect = student.contains(hpa);
    return MetarAnswerResult(
      questionId: MetarQuestionId.qnh,
      studentAnswer: student,
      correctAnswer: correct,
      explanation:
          '${m.group(0)} = $hpa hPa. QNH is the altimeter setting that reads '
          'airfield elevation when on the ground. Set before takeoff.',
      isCorrect: isCorrect,
    );
  }

  MetarAnswerResult _gradeVfrLegal(String student, String metar) {
    // Student VMC minima for Class G airspace below 3000ft AMSL / 1000ft AGL:
    //   Visibility >= 1500 m, clear of cloud.
    // Simplified assessment from METAR data.

    bool hasLowVis = false;
    bool hasBrokenOrOvercast = false;
    bool hasCavok = metar.contains('CAVOK');
    bool hasSkc = RegExp(r'\b(SKC|NSC|NCD)\b').hasMatch(metar);

    // Visibility check
    if (!hasCavok) {
      final visRe = RegExp(r'\b(9999|\d{4})\b');
      final vm = visRe.firstMatch(metar);
      if (vm != null) {
        final visM = int.tryParse(vm.group(1)!) ?? 9999;
        hasLowVis = visM < 1500;
      }
    }

    // Cloud check: BKN or OVC at any level = not clear of cloud
    if (!hasCavok && !hasSkc) {
      hasBrokenOrOvercast =
          RegExp(r'\b(BKN|OVC)\d{3}\b').hasMatch(metar);
    }

    final String legalStatus;
    final String explanation;

    if (hasCavok || (hasSkc && !hasLowVis)) {
      legalStatus = 'Yes';
      explanation =
          'CAVOK or clear sky with good visibility — VFR legal for a student '
          'pilot in Class G airspace (VMC: ≥1500 m vis, clear of cloud).';
    } else if (hasLowVis) {
      legalStatus = 'No';
      explanation =
          'Visibility is below the 1500 m VMC minimum for student pilots '
          'operating in Class G airspace below 3000 ft AMSL / 1000 ft AGL.';
    } else if (hasBrokenOrOvercast) {
      legalStatus = 'Marginal';
      explanation =
          'BKN or OVC cloud layer present. Visibility may be adequate but '
          'cloud proximity makes VFR operation marginal. '
          'Student pilots should consult an instructor before flight.';
    } else {
      legalStatus = 'Marginal';
      explanation =
          'Weather appears borderline for student VFR operations. '
          'Visibility and cloud base should be verified against '
          'current VMC minima for the airspace class.';
    }

    final studentLower = student.toLowerCase();
    final isCorrect = studentLower.contains(legalStatus.toLowerCase()) ||
        (legalStatus == 'Yes' && studentLower.contains('legal')) ||
        (legalStatus == 'No' && studentLower.contains('illegal'));

    return MetarAnswerResult(
      questionId: MetarQuestionId.vfrLegal,
      studentAnswer: student,
      correctAnswer: legalStatus,
      explanation: explanation,
      isCorrect: isCorrect,
    );
  }

  String _cloudCoverFull(String abbr) {
    switch (abbr) {
      case 'FEW':
        return 'Few (1–2 oktas)';
      case 'SCT':
        return 'Scattered (3–4 oktas)';
      case 'BKN':
        return 'Broken (5–7 oktas)';
      case 'OVC':
        return 'Overcast (8 oktas)';
      default:
        return abbr;
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod provider
// ---------------------------------------------------------------------------

/// Provides the [MetarNotifier] and its [MetarSessionState].
final metarProvider =
    StateNotifierProvider<MetarNotifier, MetarSessionState>((ref) {
  final avwx = ref.watch(avwxServiceProvider);
  final user = ref.watch(appUserProvider).valueOrNull;
  final homeIcao = (user != null && user.airfieldIcao.isNotEmpty)
      ? user.airfieldIcao.toUpperCase()
      : 'EGTC';
  return MetarNotifier(avwx, ref, initialIcao: homeIcao);
});


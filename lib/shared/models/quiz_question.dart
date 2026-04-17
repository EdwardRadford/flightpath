// Quiz question model — maps to documents in the Firestore `quiz_questions`
// collection. Supports multiple-choice and true/false formats.
//
// SCHEMA (matches seed.js as of 2026-04-13):
//   id            : String  — doc ID (e.g. 'ex_01_q3')
//   exercise_id   : String  — links to exercise_content (e.g. 'ex_01')
//   question_text : String  — the question prompt
//   question_type : String  — 'multiple_choice' | 'true_false'
//   options       : List<String> — 2 (T/F) or 4 (MC) display strings, each
//                   typically prefixed 'A. ', 'B. ', etc.
//   correct_answer: String  — the full matching string from `options`
//   explanation   : String  — shown after answering
//   difficulty    : String  — 'EASY' | 'MEDIUM' | 'HARD' (optional; defaults MEDIUM)
//   subject       : String  — CAP 1298 subject taxonomy (optional; defaults 'General')
//
// Matching is INDEX-BASED internally: we parse the seed's string-based
// `correct_answer` into an int index at load time, so UI comparison is
// whitespace/punctuation-proof.
//
// NO toFirestore() — this collection is never written to by the app.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Discriminator for question format.
enum QuestionType { multipleChoice, trueFalse }

/// A single quiz question with answer options and explanation.
class QuizQuestion {
  final String id;
  final String exerciseId;
  final String? subExercise;

  /// The question prompt text.
  final String questionText;

  final QuestionType questionType;

  /// Ordered list of answer options as they should be displayed.
  /// Length 4 for multiple choice, length 2 for true/false.
  final List<String> answers;

  /// Index into [answers] of the correct option. Always in range
  /// `0..answers.length-1`.
  final int correctAnswerIndex;

  final String explanation;
  final String difficulty;
  final String subject;
  final DateTime? createdAt;

  const QuizQuestion({
    required this.id,
    required this.exerciseId,
    this.subExercise,
    required this.questionText,
    required this.questionType,
    required this.answers,
    required this.correctAnswerIndex,
    required this.explanation,
    this.difficulty = 'MEDIUM',
    this.subject = 'General',
    this.createdAt,
  });

  // ---------------------------------------------------------------------------
  // Back-compat aliases for existing UI code that was written against the old
  // string-key schema. New code should prefer `questionText`, `answers`, and
  // `correctAnswerIndex` directly.
  // ---------------------------------------------------------------------------

  /// Alias for [questionText] — kept so legacy screens that read `q.question`
  /// keep working.
  String get question => questionText;

  /// The display string of the correct answer (e.g. 'A. Ailerons, elevator,
  /// rudder'). Useful for results/review screens.
  String get correctAnswerText =>
      (correctAnswerIndex >= 0 && correctAnswerIndex < answers.length)
          ? answers[correctAnswerIndex]
          : '';

  /// Legacy string-key form of the correct answer. Returns the stringified
  /// index (`'0'`, `'1'`, …) so that equality comparisons against
  /// `selectedAnswers[i]` — which UI code stores as the option's `key` — still
  /// work correctly. UI layers that need the human display text should use
  /// [correctAnswerText] instead.
  String get correctAnswer => correctAnswerIndex.toString();

  /// Returns answer options as (key, label) pairs for display. The `key` is
  /// the stringified option index so it is stable and whitespace-proof — UI
  /// code should record the key of the tapped option and compare it against
  /// [correctAnswer].
  List<MapEntry<String, String>> get options => [
        for (int i = 0; i < answers.length; i++)
          MapEntry(i.toString(), answers[i]),
      ];

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Infers question type from the document data, preferring the explicit
  /// `question_type` field when present.
  static QuestionType _parseQuestionType(Map<String, dynamic> data) {
    final declared = (data['question_type'] ?? '').toString().toLowerCase();
    if (declared == 'true_false') return QuestionType.trueFalse;
    if (declared == 'multiple_choice') return QuestionType.multipleChoice;
    // Fallback — two-option docs are almost certainly true/false.
    final opts = data['options'];
    if (opts is List && opts.length == 2) return QuestionType.trueFalse;
    return QuestionType.multipleChoice;
  }

  /// Reads the `options` list from raw document data. Supports both the
  /// seed.js array form (`options: ['A. …', 'B. …', …]`) and the legacy
  /// per-letter form (`option_a`, `option_b`, …) so older cached docs keep
  /// deserialising until the next refresh.
  static List<String> _parseAnswers(Map<String, dynamic> data) {
    final raw = data['options'];
    if (raw is List) {
      return raw.map((e) => (e ?? '').toString()).toList();
    }
    // Legacy shape — build from option_a..option_d.
    final legacy = <String>[];
    for (final k in ['option_a', 'option_b', 'option_c', 'option_d']) {
      final v = data[k];
      if (v != null && v.toString().isNotEmpty) legacy.add(v.toString());
    }
    if (legacy.isNotEmpty) return legacy;
    // Last-ditch default for true/false docs that only stored the correct_answer.
    final ca = (data['correct_answer'] ?? '').toString().toLowerCase().trim();
    if (ca == 'true' || ca == 'false') return const ['True', 'False'];
    return const [];
  }

  /// Resolves the correct answer index given the raw document data and the
  /// parsed [answers] list. Handles all of:
  ///   - seed.js full-string form ('A. Ailerons, elevator, rudder')
  ///   - legacy letter-key form ('a' / 'b' / 'c' / 'd')
  ///   - legacy true/false word form ('true' / 'false')
  ///   - already-numeric form (int or numeric string, for forward compat)
  ///
  /// Returns 0 as a safe fallback if nothing resolves — better to mis-mark a
  /// single question than to crash the whole quiz screen on a malformed doc.
  static int _resolveCorrectIndex(
    Map<String, dynamic> data,
    List<String> answers,
    QuestionType type,
  ) {
    final raw = data['correct_answer'];
    if (raw == null) return 0;

    // Forward-compat: seed.js might one day store an int index directly.
    if (raw is int) {
      return (raw >= 0 && raw < answers.length) ? raw : 0;
    }

    final s = raw.toString().trim();
    if (s.isEmpty) return 0;

    // Numeric string ('0', '1', ...)
    final asInt = int.tryParse(s);
    if (asInt != null && asInt >= 0 && asInt < answers.length) return asInt;

    // Exact match against an answer string (seed.js current form).
    for (int i = 0; i < answers.length; i++) {
      if (answers[i] == s) return i;
    }

    // Case-insensitive / whitespace-insensitive match.
    final norm = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    for (int i = 0; i < answers.length; i++) {
      final candidate =
          answers[i].toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      if (candidate == norm) return i;
    }

    // Legacy letter form — 'a'/'b'/'c'/'d' → 0/1/2/3
    final lower = s.toLowerCase();
    if (lower.length == 1 && RegExp(r'[a-d]').hasMatch(lower)) {
      final idx = lower.codeUnitAt(0) - 'a'.codeUnitAt(0);
      if (idx < answers.length) return idx;
    }

    // Legacy true/false word form
    if (type == QuestionType.trueFalse) {
      if (lower == 'true') return 0;
      if (lower == 'false') return answers.length >= 2 ? 1 : 0;
    }

    // Letter-prefix match ('A. …' style) where the answer string starts with
    // the same letter as the raw value.
    if (lower.isNotEmpty) {
      final firstChar = lower[0];
      for (int i = 0; i < answers.length; i++) {
        final a = answers[i].trim().toLowerCase();
        if (a.startsWith('$firstChar.') || a.startsWith('$firstChar)')) {
          return i;
        }
      }
    }

    return 0;
  }

  /// Builds a [QuizQuestion] from a raw Firestore/Hive map.
  static QuizQuestion _fromData(String docId, Map<String, dynamic> data) {
    final type = _parseQuestionType(data);
    final answers = _parseAnswers(data);
    final correctIndex = _resolveCorrectIndex(data, answers, type);

    // Accept both `question_text` (seed.js) and legacy `question`.
    final text = (data['question_text'] ?? data['question'] ?? '').toString();

    return QuizQuestion(
      id: (data['id'] as String?) ?? docId,
      exerciseId: (data['exercise_id'] ?? '').toString(),
      subExercise: data['sub_exercise'] as String?,
      questionText: text,
      questionType: type,
      answers: answers,
      correctAnswerIndex: correctIndex,
      explanation: (data['explanation'] ?? '').toString(),
      difficulty: (data['difficulty'] ?? 'MEDIUM').toString(),
      subject: (data['subject'] ?? 'General').toString(),
      createdAt: data['created_at'] is Timestamp
          ? (data['created_at'] as Timestamp).toDate()
          : (data['created_at'] is String
              ? DateTime.tryParse(data['created_at'] as String)
              : null),
    );
  }

  /// Constructs a [QuizQuestion] from a Firestore document snapshot.
  factory QuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    return _fromData(doc.id, raw as Map<String, dynamic>);
  }

  /// Constructs a [QuizQuestion] from a plain map (e.g. from Hive cache).
  /// The [docId] is used as the question ID when the map does not carry one.
  factory QuizQuestion.fromMap(String docId, Map<String, dynamic> data) =>
      _fromData(docId, data);

  /// Serialises this question to a plain map for Hive caching. We store the
  /// seed.js-shaped fields so cached docs round-trip cleanly through
  /// [fromMap] / [fromFirestore] on the next launch.
  Map<String, dynamic> toMap() => {
        'id': id,
        'exercise_id': exerciseId,
        if (subExercise != null) 'sub_exercise': subExercise,
        'question_text': questionText,
        'question_type': questionType == QuestionType.trueFalse
            ? 'true_false'
            : 'multiple_choice',
        'options': answers,
        'correct_answer': correctAnswerText,
        'explanation': explanation,
        'difficulty': difficulty,
        'subject': subject,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  /// Returns a copy with the given fields replaced.
  QuizQuestion copyWith({
    String? id,
    String? exerciseId,
    String? subExercise,
    String? questionText,
    QuestionType? questionType,
    List<String>? answers,
    int? correctAnswerIndex,
    String? explanation,
    String? difficulty,
    String? subject,
    DateTime? createdAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      subExercise: subExercise ?? this.subExercise,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      answers: answers ?? this.answers,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      explanation: explanation ?? this.explanation,
      difficulty: difficulty ?? this.difficulty,
      subject: subject ?? this.subject,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

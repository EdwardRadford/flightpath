// Quiz question model — maps to documents in the Firestore `quiz_questions`
// collection. Supports multiple-choice and true/false formats.
// NO toFirestore() — this collection is never written to by the app.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Discriminator for question format.
enum QuestionType { multipleChoice, trueFalse }

/// A single quiz question with answer options and explanation.
class QuizQuestion {
  final String id;
  final String exerciseId;
  final String? subExercise;
  final String question;
  final QuestionType questionType;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String correctAnswer; // 'a' | 'b' | 'c' | 'd' | 'true' | 'false'
  final String explanation;
  final DateTime? createdAt;

  const QuizQuestion({
    required this.id,
    required this.exerciseId,
    this.subExercise,
    required this.question,
    required this.questionType,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    required this.correctAnswer,
    required this.explanation,
    this.createdAt,
  });

  /// Infers question type from the document data.
  ///
  /// Treats as trueFalse if [question_type] is 'true_false' OR if the
  /// correct_answer is 'true'/'false' (handles legacy documents with missing
  /// or incorrect question_type fields).
  static QuestionType _parseQuestionType(Map<String, dynamic> data) {
    if (data['question_type'] == 'true_false') return QuestionType.trueFalse;
    final ca = (data['correct_answer'] ?? '').toString().toLowerCase().trim();
    if (ca == 'true' || ca == 'false') return QuestionType.trueFalse;
    return QuestionType.multipleChoice;
  }

  /// Constructs a [QuizQuestion] from a Firestore document snapshot.
  factory QuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    final type = _parseQuestionType(data);
    return QuizQuestion(
      id: doc.id,
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      question: data['question'] ?? '',
      questionType: type,
      optionA: data['option_a'],
      optionB: data['option_b'],
      optionC: data['option_c'],
      optionD: data['option_d'],
      correctAnswer: _normaliseCorrectAnswer(
        data['correct_answer'] ?? '',
        type,
      ),
      explanation: data['explanation'] ?? '',
      createdAt: (data['created_at'] as Timestamp?)?.toDate(),
    );
  }

  /// Normalises the correct answer key for true/false questions.
  /// Firestore documents sometimes store 'a'/'b' for option A (True)/B (False).
  static String _normaliseCorrectAnswer(String raw, QuestionType type) {
    if (type != QuestionType.trueFalse) return raw;
    final v = raw.toLowerCase().trim();
    if (v == 'a') return 'true';
    if (v == 'b') return 'false';
    return v;
  }

  /// Constructs a [QuizQuestion] from a plain map (e.g. from Hive cache).
  /// The [docId] is used as the question ID since maps don't carry doc refs.
  factory QuizQuestion.fromMap(String docId, Map<String, dynamic> data) {
    final type = _parseQuestionType(data);
    return QuizQuestion(
      id: data['id'] as String? ?? docId,
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      question: data['question'] ?? '',
      questionType: type,
      optionA: data['option_a'],
      optionB: data['option_b'],
      optionC: data['option_c'],
      optionD: data['option_d'],
      correctAnswer: _normaliseCorrectAnswer(
        data['correct_answer'] ?? '',
        type,
      ),
      explanation: data['explanation'] ?? '',
      createdAt: data['created_at'] is String
          ? DateTime.tryParse(data['created_at'] as String)
          : null,
    );
  }

  /// Serialises this question to a plain map for Hive caching.
  Map<String, dynamic> toMap() => {
        'id': id,
        'exercise_id': exerciseId,
        if (subExercise != null) 'sub_exercise': subExercise,
        'question': question,
        'question_type':
            questionType == QuestionType.trueFalse ? 'true_false' : 'multiple_choice',
        if (optionA != null) 'option_a': optionA,
        if (optionB != null) 'option_b': optionB,
        if (optionC != null) 'option_c': optionC,
        if (optionD != null) 'option_d': optionD,
        'correct_answer': correctAnswer,
        'explanation': explanation,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  /// Returns answer options as (key, label) pairs for display.
  List<MapEntry<String, String>> get options {
    if (questionType == QuestionType.trueFalse) {
      return [
        const MapEntry('true', 'True'),
        const MapEntry('false', 'False'),
      ];
    }
    return [
      if (optionA != null) MapEntry('a', optionA!),
      if (optionB != null) MapEntry('b', optionB!),
      if (optionC != null) MapEntry('c', optionC!),
      if (optionD != null) MapEntry('d', optionD!),
    ];
  }

  /// Returns a copy with the given fields replaced.
  QuizQuestion copyWith({
    String? id,
    String? exerciseId,
    String? subExercise,
    String? question,
    QuestionType? questionType,
    String? optionA,
    String? optionB,
    String? optionC,
    String? optionD,
    String? correctAnswer,
    String? explanation,
    DateTime? createdAt,
  }) {
    return QuizQuestion(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      subExercise: subExercise ?? this.subExercise,
      question: question ?? this.question,
      questionType: questionType ?? this.questionType,
      optionA: optionA ?? this.optionA,
      optionB: optionB ?? this.optionB,
      optionC: optionC ?? this.optionC,
      optionD: optionD ?? this.optionD,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

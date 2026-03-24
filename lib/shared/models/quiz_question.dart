// Quiz question model — maps to documents in the Firestore `quiz_questions`
// collection. Supports multiple-choice and true/false formats.
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
  });

  /// Constructs a [QuizQuestion] from a Firestore document snapshot.
  factory QuizQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QuizQuestion(
      id: doc.id,
      exerciseId: data['exercise_id'] ?? '',
      subExercise: data['sub_exercise'],
      question: data['question'] ?? '',
      questionType: data['question_type'] == 'true_false'
          ? QuestionType.trueFalse
          : QuestionType.multipleChoice,
      optionA: data['option_a'],
      optionB: data['option_b'],
      optionC: data['option_c'],
      optionD: data['option_d'],
      correctAnswer: data['correct_answer'] ?? '',
      explanation: data['explanation'] ?? '',
    );
  }

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
}

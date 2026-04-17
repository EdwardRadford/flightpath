// Flashcard model — maps to documents in the Firestore `flashcards` collection.
//
// SCHEMA (matches seed.js):
//   id          : String  — doc ID (e.g. 'ex_01_fc_0')
//   exercise_id : String  — links to exercise_content (e.g. 'ex_01')
//   front       : String  — question text shown on the card face
//   back        : String  — answer text shown after flip
//
// NO toFirestore() — this collection is never written to by the app.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single flashcard with a question (front) and answer (back).
class Flashcard {
  final String id;
  final String front;
  final String back;
  final String exerciseId;

  Flashcard({
    this.id = '',
    required this.front,
    required this.back,
    required this.exerciseId,
  });

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  static Flashcard _fromData(String docId, Map<String, dynamic> data) {
    return Flashcard(
      id: (data['id'] as String?) ?? docId,
      front: (data['front'] ?? '').toString(),
      back: (data['back'] ?? '').toString(),
      exerciseId: (data['exercise_id'] ?? '').toString(),
    );
  }

  /// Constructs a [Flashcard] from a Firestore document snapshot.
  factory Flashcard.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    return _fromData(doc.id, raw as Map<String, dynamic>);
  }

  /// Constructs a [Flashcard] from a plain map (e.g. from Hive cache).
  factory Flashcard.fromMap(String docId, Map<String, dynamic> data) =>
      _fromData(docId, data);

  /// Serialises this flashcard to a plain map for Hive caching.
  Map<String, dynamic> toMap() => {
        'id': id,
        'exercise_id': exerciseId,
        'front': front,
        'back': back,
      };
}

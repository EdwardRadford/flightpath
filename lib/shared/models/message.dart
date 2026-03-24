// Message model — maps to documents in the Firestore `messages` collection.
// Supports instructor-student messaging with optional exercise/lesson context.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single message between an instructor and a student.
class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool read;
  final String? exerciseId;
  final String? lessonId;

  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.read,
    this.exerciseId,
    this.lessonId,
  });

  /// Constructs a [Message] from a Firestore document snapshot.
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['sender_id'] ?? '',
      recipientId: data['recipient_id'] ?? '',
      senderName: data['sender_name'] ?? '',
      message: data['message'] ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
      exerciseId: data['exercise_id'],
      lessonId: data['lesson_id'],
    );
  }

  /// Serialises this message to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
        'sender_id': senderId,
        'recipient_id': recipientId,
        'sender_name': senderName,
        'message': message,
        'created_at': Timestamp.fromDate(createdAt),
        'read': read,
        if (exerciseId != null) 'exercise_id': exerciseId,
        if (lessonId != null) 'lesson_id': lessonId,
      };
}

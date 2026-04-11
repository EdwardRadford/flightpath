// Message model — maps to `conversations/{conversationId}/messages/{messageId}`.
// Updated for new schema: stripped down to core fields, no recipientId/senderName.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A single message within a [Conversation] thread.
class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final bool read;

  const Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.read = false,
  });

  /// Constructs a [Message] from a Firestore document snapshot.
  factory Message.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderId: data['sender_id'] ?? '',
      content: data['content'] ?? '',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  /// Serialises this message to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'sender_id': senderId,
    'content': content,
    'created_at': Timestamp.fromDate(createdAt),
    'read': read,
  };

  /// Returns a copy with the given fields replaced.
  Message copyWith({
    String? id,
    String? senderId,
    String? content,
    DateTime? createdAt,
    bool? read,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      read: read ?? this.read,
    );
  }
}

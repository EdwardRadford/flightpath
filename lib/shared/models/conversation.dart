// Conversation model — maps to `conversations/{conversationId}`.
// Replaces the old flat `messages` collection.
// Messages live in the subcollection `conversations/{id}/messages/{id}`.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A messaging thread between two or more participants.
class Conversation {
  final String id;
  final List<String> participantIds;
  final DateTime createdAt;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;

  const Conversation({
    required this.id,
    required this.participantIds,
    required this.createdAt,
    this.lastMessageAt,
    this.lastMessagePreview,
  });

  /// Constructs a [Conversation] from a Firestore document snapshot.
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      participantIds: List<String>.from(data['participant_ids'] ?? []),
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastMessageAt: (data['last_message_at'] as Timestamp?)?.toDate(),
      lastMessagePreview: data['last_message_preview'],
    );
  }

  /// Serialises this conversation to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'participant_ids': participantIds,
    'created_at': Timestamp.fromDate(createdAt),
    if (lastMessageAt != null)
      'last_message_at': Timestamp.fromDate(lastMessageAt!),
    if (lastMessagePreview != null)
      'last_message_preview': lastMessagePreview,
  };

  /// Returns a copy with the given fields replaced.
  Conversation copyWith({
    String? id,
    List<String>? participantIds,
    DateTime? createdAt,
    DateTime? lastMessageAt,
    String? lastMessagePreview,
  }) {
    return Conversation(
      id: id ?? this.id,
      participantIds: participantIds ?? this.participantIds,
      createdAt: createdAt ?? this.createdAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
    );
  }
}

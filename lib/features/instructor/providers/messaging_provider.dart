// Messaging providers — Firestore CRUD for the `messages` collection.
// Supports real-time conversation streams and unread count badges.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flight_path/features/auth/providers/auth_provider.dart';
import 'package:flight_path/shared/models/message.dart';
import 'package:flight_path/shared/utils/input_sanitiser.dart';

final _db = FirebaseFirestore.instance;

// ---------------------------------------------------------------------------
// Conversation stream — messages between the current user and another user
// ---------------------------------------------------------------------------

/// Streams messages between the current user and [otherUserId], ordered by
/// creation time ascending (oldest first).
final conversationProvider =
    StreamProvider.family<List<Message>, String>((ref, otherUserId) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value([]);

  // We need two queries: messages I sent to them, and messages they sent to me.
  // Firestore doesn't support OR queries across different fields, so we
  // combine two streams.
  final sentStream = _db
      .collection('messages')
      .where('sender_id', isEqualTo: uid)
      .where('recipient_id', isEqualTo: otherUserId)
      .orderBy('created_at')
      .snapshots();

  final receivedStream = _db
      .collection('messages')
      .where('sender_id', isEqualTo: otherUserId)
      .where('recipient_id', isEqualTo: uid)
      .orderBy('created_at')
      .snapshots();

  // Merge both streams by combining their latest snapshots.
  return sentStream.asyncExpand((sentSnap) {
    return receivedStream.map((receivedSnap) {
      final allDocs = [...sentSnap.docs, ...receivedSnap.docs];
      final messages =
          allDocs.map((doc) => Message.fromFirestore(doc)).toList();
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return messages;
    });
  });
});

// ---------------------------------------------------------------------------
// Unread count — total unread messages for the current user
// ---------------------------------------------------------------------------

/// Streams the count of unread messages addressed to the current user.
final unreadCountProvider = StreamProvider<int>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  if (uid == null) return Stream.value(0);

  return _db
      .collection('messages')
      .where('recipient_id', isEqualTo: uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((qs) => qs.docs.length);
});

// ---------------------------------------------------------------------------
// Service functions
// ---------------------------------------------------------------------------

/// Sends a message from the current user to the recipient.
/// Defence-in-depth: sanitises the message text before writing to Firestore.
Future<void> sendMessage({
  required String senderId,
  required String senderName,
  required String recipientId,
  required String message,
  String? exerciseId,
  String? lessonId,
}) async {
  final sanitised = InputSanitiser.sanitise(
    message,
    maxLength: InputSanitiser.maxMedium,
  );
  if (sanitised.isEmpty) return; // Refuse to send empty messages.

  await _db.collection('messages').add({
    'sender_id': senderId,
    'recipient_id': recipientId,
    'sender_name': sanitised.length <= InputSanitiser.maxName
        ? senderName
        : senderName.substring(0, InputSanitiser.maxName),
    'message': sanitised,
    'created_at': FieldValue.serverTimestamp(),
    'read': false,
    'exercise_id': ?exerciseId,
    'lesson_id': ?lessonId,
  });
}

/// Marks a specific message as read.
Future<void> markAsRead(String messageId) async {
  await _db.collection('messages').doc(messageId).update({'read': true});
}

/// Marks all unread messages from [otherUserId] to [currentUserId] as read.
Future<void> markConversationAsRead({
  required String currentUserId,
  required String otherUserId,
}) async {
  final unread = await _db
      .collection('messages')
      .where('sender_id', isEqualTo: otherUserId)
      .where('recipient_id', isEqualTo: currentUserId)
      .where('read', isEqualTo: false)
      .get();

  final batch = _db.batch();
  for (final doc in unread.docs) {
    batch.update(doc.reference, {'read': true});
  }
  await batch.commit();
}

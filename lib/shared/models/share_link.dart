// Share link model — maps to `share_links/{linkId}`.
// Kept top-level because it is publicly accessible without auth.
import 'package:cloud_firestore/cloud_firestore.dart';

/// A shareable link that lets a non-authenticated viewer see a snapshot of
/// a student's training progress.
class ShareLink {
  final String id;
  final String userId;
  final bool isActive;
  final DateTime expiresAt;
  final String sharedProgressJson;

  const ShareLink({
    required this.id,
    required this.userId,
    required this.isActive,
    required this.expiresAt,
    required this.sharedProgressJson,
  });

  /// Constructs a [ShareLink] from a Firestore document snapshot.
  factory ShareLink.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) throw StateError('Document ${doc.id} has no data');
    final data = raw as Map<String, dynamic>;
    return ShareLink(
      id: doc.id,
      userId: data['user_id'] ?? '',
      isActive: data['is_active'] ?? false,
      expiresAt:
          (data['expires_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      sharedProgressJson: data['shared_progress_json'] ?? '',
    );
  }

  /// Serialises this share link to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() => {
    'user_id': userId,
    'is_active': isActive,
    'expires_at': Timestamp.fromDate(expiresAt),
    'shared_progress_json': sharedProgressJson,
  };

  /// Returns a copy with the given fields replaced.
  ShareLink copyWith({
    String? id,
    String? userId,
    bool? isActive,
    DateTime? expiresAt,
    String? sharedProgressJson,
  }) {
    return ShareLink(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      sharedProgressJson: sharedProgressJson ?? this.sharedProgressJson,
    );
  }
}

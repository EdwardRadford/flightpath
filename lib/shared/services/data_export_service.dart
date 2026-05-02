// GDPR Article 20 — data portability service.
// Fetches all user data from Firestore, formats it as JSON, and shares via
// the native share sheet or saves to a temporary file.
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports all user data as a JSON file and opens the native share sheet.
class DataExportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Collects all data belonging to [uid] and returns it as a formatted JSON
  /// string. The structure mirrors Firestore collections so the user can
  /// understand their data at a glance.
  Future<Map<String, dynamic>> _collectUserData(String uid) async {
    final export = <String, dynamic>{
      'export_date': DateTime.now().toIso8601String(),
      'format_version': 1,
    };

    // 1. Profile
    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      export['profile'] = _sanitiseTimestamps(userDoc.data()!);
    }

    // 2. Lessons — new subcollection path: users/{uid}/lessons
    final lessonsSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('lessons')
        .get();
    final lessonDocs = [...lessonsSnap.docs]
      ..sort((a, b) {
        final aTs = a.data()['created_at'];
        final bTs = b.data()['created_at'];
        if (aTs == null || bTs == null) return 0;
        return (bTs as Timestamp).compareTo(aTs as Timestamp);
      });
    export['lessons'] = lessonDocs
        .map((d) => _sanitiseTimestamps({...d.data(), 'id': d.id}))
        .toList();

    // 3. User exercises — new subcollection path: users/{uid}/exercises
    final exercisesSnap = await _db
        .collection('users')
        .doc(uid)
        .collection('exercises')
        .get();
    export['user_exercises'] = exercisesSnap.docs
        .map((d) => _sanitiseTimestamps({...d.data(), 'id': d.id}))
        .toList();

    // 4. Share links
    final shareLinksSnap = await _db
        .collection('share_links')
        .where('user_id', isEqualTo: uid)
        .get();
    export['share_links'] = shareLinksSnap.docs
        .map((d) => _sanitiseTimestamps({...d.data(), 'id': d.id}))
        .toList();

    return export;
  }

  /// Converts Firestore [Timestamp] values to ISO 8601 strings so the JSON
  /// is human-readable and parseable by any JSON consumer.
  Map<String, dynamic> _sanitiseTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) {
      if (value is Timestamp) {
        return MapEntry(key, value.toDate().toIso8601String());
      }
      if (value is Map<String, dynamic>) {
        return MapEntry(key, _sanitiseTimestamps(value));
      }
      if (value is List) {
        return MapEntry(
          key,
          value.map((e) {
            if (e is Timestamp) return e.toDate().toIso8601String();
            if (e is Map<String, dynamic>) return _sanitiseTimestamps(e);
            return e;
          }).toList(),
        );
      }
      return MapEntry(key, value);
    });
  }

  /// Fetches all user data, writes it to a temporary JSON file, and opens the
  /// native share sheet so the user can save or send it.
  ///
  /// Throws on network errors or if the share sheet cannot be opened.
  Future<void> exportAndShare(String uid) async {
    try {
      final data = await _collectUserData(uid);
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Write to a temp file so share_plus can attach it.
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/flight_path_data_export.json');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Flight Path Training — My Data Export',
        ),
      );
    } catch (e, stack) {
      debugPrint('DataExportService: export failed: $e');
      FirebaseCrashlytics.instance.recordError(e, stack,
          reason: 'GDPR data export failed');
      rethrow;
    }
  }
}

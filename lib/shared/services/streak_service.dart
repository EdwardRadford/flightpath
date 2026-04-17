import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flight_path/shared/models/app_user.dart';
import 'package:flight_path/shared/services/firestore_service.dart';

class StreakService {
  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _isYesterday(DateTime candidate, DateTime today) {
    final yesterday = today.subtract(const Duration(days: 1));
    return _isSameDay(candidate, yesterday);
  }

  static Future<void> updateStreakIfNeeded(
    String uid,
    AppUser user,
    FirestoreService firestoreService,
  ) async {
    final today = DateTime.now();
    final last = user.lastActiveDate;

    if (last != null && _isSameDay(last, today)) return;

    final int newStreak;
    if (last != null && _isYesterday(last, today)) {
      newStreak = user.studyStreak + 1;
    } else {
      newStreak = 1;
    }

    await firestoreService.updateUser(uid, {
      'study_streak': newStreak,
      'last_active_date': Timestamp.fromDate(
        DateTime(today.year, today.month, today.day),
      ),
    });
  }
}

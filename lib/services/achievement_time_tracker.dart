import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Records the local-time window a genuine, tracked hunter action falls
/// into, backing the three hidden "time of day" achievements
/// (`hidden_midnight`, `hidden_early_bird`, `hidden_night_owl`).
///
/// This is intentionally a tiny, single-purpose helper (not a full service)
/// — call [recordNow] from any real trigger site right after that site's own
/// Firestore write completes (quest completion, water log, weight log, run
/// save, duel completion, step milestone, etc.). It only ever flips a field
/// from false to true (never resets), and skips the write entirely once a
/// window's field is already true, so it never generates redundant writes
/// for a hunter who has already qualified for a given window.
class AchievementTimeTracker {
  AchievementTimeTracker._();

  /// Midnight window: 00:00–02:59 local time.
  static bool _isMidnightWindow(DateTime t) => t.hour >= 0 && t.hour < 3;

  /// Early-bird window: 04:00–05:59 local time.
  static bool _isEarlyBirdWindow(DateTime t) => t.hour >= 4 && t.hour < 6;

  /// Night-owl window: 23:00–23:59 local time.
  static bool _isNightOwlWindow(DateTime t) => t.hour >= 23;

  /// Checks the current local time against all three windows and writes any
  /// newly-qualifying field(s) to the hunter document. Safe to call on every
  /// tracked action — cheap no-op once a window's field is already set (the
  /// caller is expected to pass the already-known current field values via
  /// [alreadyMidnight]/[alreadyEarlyBird]/[alreadyNightOwl] to avoid an extra
  /// read; omit them to always attempt the write, which Firestore will just
  /// overwrite harmlessly with the same `true` value).
  static Future<void> recordNow({
    bool alreadyMidnight = false,
    bool alreadyEarlyBird = false,
    bool alreadyNightOwl = false,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final updates = <String, dynamic>{};

    if (!alreadyMidnight && _isMidnightWindow(now)) {
      updates['hitMidnightAction'] = true;
    }
    if (!alreadyEarlyBird && _isEarlyBirdWindow(now)) {
      updates['hitEarlyBirdAction'] = true;
    }
    if (!alreadyNightOwl && _isNightOwlWindow(now)) {
      updates['hitNightOwlAction'] = true;
    }

    if (updates.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .update(updates);
    } catch (e) {
      debugPrint('AchievementTimeTracker.recordNow: $e');
    }
  }
}

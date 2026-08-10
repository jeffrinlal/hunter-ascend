import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the authenticated user has used Hunter Ascend "today",
/// powering the Leaderboard header's "Today's Active Hunters" count.
///
/// ## Design
/// - ONE Firestore write per user per day — a local [SharedPreferences]
///   flag deduplicates every subsequent open, rebuild, and navigation
///   this same day, so the write is truly once-per-day.
/// - Activity lives in a dedicated `user_activity/{uid}` collection — it
///   never touches the hunter profile document or its security rules.
/// - "Today" = the UTC calendar day, the same boundary
///   [XpService.todayMidnightUtcEpoch] uses for the Daily leaderboard's
///   reset, so "today" means the same thing everywhere in the app.
/// - The active-user COUNT is a server-side Firestore count aggregation
///   on `where('activeDate', isEqualTo: today)` — no documents are
///   downloaded into memory.
class UserActivityService {
  UserActivityService._();
  static final UserActivityService instance = UserActivityService._();

  static const _collection = 'user_activity';
  static const _keyLastActiveDate = 'lastActiveDateUtc';

  /// Marks the current user active for today if not already marked.
  ///
  /// No-op once already active today (client-side dedup guard) — so
  /// repeated app opens, rebuilds, and navigation never produce extra
  /// Firestore writes. Fire-and-forget by design; never throws into the
  /// UI. If the Firestore write fails the local flag is left unset so a
  /// later open can retry.
  Future<void> markActiveToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = _todayUtcDateString();
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getString(_keyLastActiveDate) ?? '';
    if (last == today) return; // already active today — no write.

    try {
      await FirebaseFirestore.instance.collection(_collection).doc(uid).set({
        'activeDate': today,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await prefs.setString(_keyLastActiveDate, today);
    } catch (e) {
      debugPrint('UserActivityService.markActiveToday: $e');
      // Leave the local flag unset so a later open can retry.
    }
  }

  /// Returns the count of unique hunters active today (UTC day), or
  /// `null` on failure. Uses a Firestore count aggregation — no
  /// documents are downloaded into memory.
  Future<int?> todayActiveCount() async {
    final today = _todayUtcDateString();
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection(_collection)
              .where('activeDate', isEqualTo: today)
              .count()
              .get();
      return snapshot.count;
    } catch (e) {
      debugPrint('UserActivityService.todayActiveCount: $e');
      return null;
    }
  }

  /// Today's UTC calendar date as `yyyy-MM-dd` — the deterministic day
  /// boundary already used by [XpService.todayMidnightUtcEpoch], so
  /// "today" means the same thing here as it does for the Daily
  /// leaderboard's reset. No duplicate reset system — activity has no
  /// reset at all; it just queries the current day's records.
  static String _todayUtcDateString() {
    final now = DateTime.now().toUtc();
    return '${now.year.toString().padLeft(4, '0')}'
        '-${now.month.toString().padLeft(2, '0')}'
        '-${now.day.toString().padLeft(2, '0')}';
  }
}

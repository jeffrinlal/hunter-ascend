import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/leaderboard_repository.dart';

/// Centralized XP awarding service.
///
/// Every XP reward in the app goes through [awardXp]. This single method:
/// - Applies lazy daily reset if the current day has changed
/// - Applies lazy weekly reset if the current week has changed
/// - Increments total XP
/// - Increments daily XP (for daily leaderboard)
/// - Increments weekly XP (for weekly leaderboard)
/// - Handles level-up logic (500 XP per level)
///
/// XP deductions (discipline penalties, streak loss) do NOT go through this
/// service — they reduce XP without contributing to leaderboard progress.
///
/// ## Usage
/// ```dart
/// final result = await XpService.instance.awardXp(amount: 25);
/// if (result != null && result.leveledUp) { /* show level-up UI */ }
/// ```
class XpService {
  XpService._();
  static final XpService instance = XpService._();

  /// Awards XP to the current user atomically via a Firestore transaction.
  ///
  /// Returns the resulting XP, level, and whether a level-up occurred.
  /// Returns `null` if no user is signed in or the transaction fails.
  Future<XpAwardResult?> awardXp({required int amount}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);

    try {
      final result = await FirebaseFirestore.instance.runTransaction<XpAwardResult>((txn) async {
        final snap = await txn.get(ref);
        final data = snap.data() ?? {};

        int curXp = (data['xp'] ?? 0) as int;
        int curLevel = (data['level'] ?? 1) as int;
        final int startLevel = curLevel;

        // ── Lazy daily reset ──
        int dailyXp = (data['dailyXp'] ?? 0) as int;
        int dailyResetEpoch = (data['dailyResetEpoch'] ?? 0) as int;
        final int todayEpoch = _todayMidnightUtcEpoch();
        if (dailyResetEpoch < todayEpoch) {
          dailyXp = 0;
          dailyResetEpoch = todayEpoch;
        }

        // ── Lazy weekly reset ──
        int weeklyXp = (data['weeklyXp'] ?? 0) as int;
        int weeklyResetEpoch = (data['weeklyResetEpoch'] ?? 0) as int;
        final int mondayEpoch = _mondayMidnightUtcEpoch();
        if (weeklyResetEpoch < mondayEpoch) {
          weeklyXp = 0;
          weeklyResetEpoch = mondayEpoch;
        }

        // ── Apply XP ──
        curXp += amount;
        dailyXp += amount;
        weeklyXp += amount;

        // ── Level-up ──
        while (curXp >= 500) {
          curXp -= 500;
          curLevel++;
        }

        // ── Write atomically ──
        txn.update(ref, {
          'xp': curXp,
          'level': curLevel,
          'dailyXp': dailyXp,
          'dailyResetEpoch': dailyResetEpoch,
          'weeklyXp': weeklyXp,
          'weeklyResetEpoch': weeklyResetEpoch,
        });

        return XpAwardResult(
          xp: curXp,
          level: curLevel,
          leveledUp: curLevel > startLevel,
        );
      });

      // Mark leaderboard cache as stale so the next screen open fetches fresh data.
      LeaderboardRepository.instance.markStale();

      return result;
    } catch (e) {
      debugPrint('XpService.awardXp: $e');
      return null;
    }
  }

  /// Returns epoch milliseconds for today's midnight UTC.
  static int _todayMidnightUtcEpoch() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  /// Returns epoch milliseconds for this week's Monday midnight UTC.
  static int _mondayMidnightUtcEpoch() {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime.utc(monday.year, monday.month, monday.day).millisecondsSinceEpoch;
  }
}

/// Result of an XP award operation.
class XpAwardResult {
  const XpAwardResult({
    required this.xp,
    required this.level,
    required this.leveledUp,
  });

  final int xp;
  final int level;
  final bool leveledUp;
}

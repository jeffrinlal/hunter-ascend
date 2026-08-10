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
/// - Increments weekly XP (kept on the hunter document; the weekly
///   leaderboard tab no longer exists)
/// - Optionally increments the PERMANENT dungeon leaderboard score
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
  /// [dungeonScore] optionally adds permanent ALL-TIME dungeon leaderboard
  /// points in the SAME transaction (used by the dungeon clear claim, so
  /// the score can never be paid twice or drift from the XP award).
  /// Dungeon scores never reset — no period key, no expiry.
  ///
  /// Returns the resulting XP, level, and whether a level-up occurred.
  /// Returns `null` if no user is signed in or the transaction fails.
  Future<XpAwardResult?> awardXp({
    required int amount,
    int dungeonScore = 0,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final ref = FirebaseFirestore.instance.collection('hunters').doc(uid);

    try {
      final result = await FirebaseFirestore.instance
          .runTransaction<XpAwardResult>((txn) async {
            final snap = await txn.get(ref);
            final data = snap.data() ?? {};

            int curXp = (data['xp'] ?? 0) as int;
            int curLevel = (data['level'] ?? 1) as int;
            final int startLevel = curLevel;

            // ── Lazy daily reset ──
            int dailyXp = (data['dailyXp'] ?? 0) as int;
            int dailyResetEpoch = (data['dailyResetEpoch'] ?? 0) as int;
            final int todayEpoch = todayMidnightUtcEpoch();
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
            final updates = <String, dynamic>{
              'xp': curXp,
              'level': curLevel,
              'dailyXp': dailyXp,
              'dailyResetEpoch': dailyResetEpoch,
              'weeklyXp': weeklyXp,
              'weeklyResetEpoch': weeklyResetEpoch,
            };
            // Permanent dungeon leaderboard score — only ever written on a
            // claimed dungeon clear; it has NO reset mechanism by design.
            if (dungeonScore > 0) {
              updates['dungeonScore'] = FieldValue.increment(dungeonScore);
            }
            txn.update(ref, updates);

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

  /// Epoch milliseconds for today's midnight UTC — the deterministic
  /// 24-hour period boundary shared by the lazy daily reset above and
  /// the Daily leaderboard query (a hunter's `dailyXp` only counts while
  /// their `dailyResetEpoch` equals this value).
  static int todayMidnightUtcEpoch() {
    final now = DateTime.now().toUtc();
    return DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch;
  }

  /// Returns epoch milliseconds for this week's Monday midnight UTC.
  static int _mondayMidnightUtcEpoch() {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return DateTime.utc(
      monday.year,
      monday.month,
      monday.day,
    ).millisecondsSinceEpoch;
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

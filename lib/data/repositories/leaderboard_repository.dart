import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/leaderboard_entry.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// Leaderboard tab identifiers.
///
/// DAILY and DUNGEON are deliberately different animals:
/// - [daily]   — time-based, current 24-hour period, resets every day.
/// - [dungeon] — ALL-TIME, permanent, NEVER resets (no period key).
enum LeaderboardTab { daily, dungeon, overall }

/// Cache-first repository for leaderboard data.
///
/// ## Design
/// - Uses one-time `.get()` queries (no real-time listeners).
/// - Caches results in Hive with a 5-minute TTL.
/// - Shows cached data instantly on screen open.
/// - Refreshes in the background when cache is stale.
/// - Generic enough for future leaderboard types (monthly, friends, etc.)
///   by extending [LeaderboardTab] and adding query methods.
///
/// ## Firestore Queries
/// - Daily: current 24-hour period ONLY (dailyResetEpoch == today's UTC
///   midnight epoch), orderBy dailyXp DESC, limit 20 — stale periods are
///   excluded server-side, deterministically.
/// - Dungeon: PERMANENT all-time, orderBy dungeonScore DESC, limit 30.
///   No period key, no reset, ever.
/// - Overall: orderBy level DESC, xp DESC, limit 30
class LeaderboardRepository {
  LeaderboardRepository._();
  static final LeaderboardRepository instance = LeaderboardRepository._();

  /// Cache TTL — data older than this triggers a background refresh.
  static const Duration cacheTtl = Duration(minutes: 5);

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns cached leaderboard data instantly (or null if never fetched).
  List<LeaderboardEntry>? getCached(LeaderboardTab tab) {
    try {
      final box = Hive.box(CacheConstants.leaderboardBox);
      final raw = box.get(_dataKey(tab));
      if (raw == null) return null;
      return (raw as List).cast<LeaderboardEntry>();
    } catch (e) {
      debugPrint('[HIVE] LeaderboardRepository.getCached ERROR: $e');
      return null;
    }
  }

  /// Whether the cached data for [tab] is stale (older than [cacheTtl]).
  bool isStale(LeaderboardTab tab) {
    try {
      final box = Hive.box(CacheConstants.leaderboardBox);
      final timestamp = box.get(_timestampKey(tab)) as int?;
      if (timestamp == null) return true;
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      return age > cacheTtl.inMilliseconds;
    } catch (_) {
      return true;
    }
  }

  /// Fetches leaderboard data from Firestore and caches it.
  /// If [forceRefresh] is false and cache is fresh, returns cached data.
  Future<List<LeaderboardEntry>> fetch(
    LeaderboardTab tab, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && !isStale(tab)) {
      final cached = getCached(tab);
      if (cached != null) return cached;
    }

    try {
      final query = _buildQuery(tab);
      final snapshot = await query.get();

      final entries =
          snapshot.docs
              .map((doc) => LeaderboardEntry.fromFirestore(doc.id, doc.data()))
              .toList();

      _writeToCache(tab, entries);
      return entries;
    } catch (e) {
      debugPrint('[HIVE] LeaderboardRepository.fetch ERROR: $e');
      // Fall back to cached data on failure.
      return getCached(tab) ?? [];
    }
  }

  /// Clears all cached leaderboard data (on logout).
  Future<void> clearCache() async {
    try {
      final box = Hive.box(CacheConstants.leaderboardBox);
      await box.clear();
    } catch (e) {
      debugPrint('[HIVE] LeaderboardRepository.clearCache ERROR: $e');
    }
  }

  /// Marks all leaderboard tabs as stale so the next [fetch] call
  /// forces a Firestore refresh. Called after XP is awarded.
  void markStale() {
    try {
      final box = Hive.box(CacheConstants.leaderboardBox);
      for (final tab in LeaderboardTab.values) {
        box.delete(_timestampKey(tab));
      }
    } catch (e) {
      debugPrint('[HIVE] LeaderboardRepository.markStale ERROR: $e');
    }
  }

  // ── Private ──────────────────────────────────────────────────────────────

  Query<Map<String, dynamic>> _buildQuery(LeaderboardTab tab) {
    final collection = FirebaseFirestore.instance.collection('hunters');
    switch (tab) {
      case LeaderboardTab.overall:
        return collection
            .orderBy('level', descending: true)
            .orderBy('xp', descending: true)
            .limit(30);
      case LeaderboardTab.daily:
        // DAILY = the CURRENT 24-hour period only. `dailyXp` is only valid
        // while a hunter's `dailyResetEpoch` matches the current period —
        // XpService zeroes `dailyXp` and stamps the epoch on the first
        // award of each new period. Filtering by the epoch therefore
        // excludes every stale score SERVER-SIDE: no dependence on anyone
        // opening the app, no client-side clearing, no duplicate reset
        // system — it IS the existing daily-reset architecture.
        return collection
            .where(
              'dailyResetEpoch',
              isEqualTo: XpService.todayMidnightUtcEpoch(),
            )
            .orderBy('dailyXp', descending: true)
            .limit(20);
      case LeaderboardTab.dungeon:
        // DUNGEON = permanent ALL-TIME score. No period key, no expiry,
        // never reset. `orderBy` on a missing field excludes documents
        // that never cleared a dungeon, so only real scores appear.
        // Limit is enforced server-side (top 30).
        return collection.orderBy('dungeonScore', descending: true).limit(30);
    }
  }

  void _writeToCache(LeaderboardTab tab, List<LeaderboardEntry> entries) {
    try {
      final box = Hive.box(CacheConstants.leaderboardBox);
      box.put(_dataKey(tab), entries);
      box.put(_timestampKey(tab), DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[HIVE] LeaderboardRepository._writeToCache ERROR: $e');
    }
  }

  String _dataKey(LeaderboardTab tab) =>
      'data_${tab.name}${_periodSuffix(tab)}';
  String _timestampKey(LeaderboardTab tab) =>
      'ts_${tab.name}${_periodSuffix(tab)}';

  /// The Daily tab's cache key is scoped to the CURRENT 24-hour period, so
  /// a period rollover can never serve yesterday's cached scores (Dungeon
  /// and Overall are permanent and cache without a period).
  String _periodSuffix(LeaderboardTab tab) =>
      tab == LeaderboardTab.daily
          ? '_${XpService.todayMidnightUtcEpoch()}'
          : '';
}

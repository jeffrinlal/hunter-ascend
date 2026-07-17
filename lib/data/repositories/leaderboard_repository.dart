import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/leaderboard_entry.dart';

/// Leaderboard tab identifiers.
enum LeaderboardTab { overall, weekly, daily }

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
/// - Overall: orderBy level DESC, xp DESC, limit 30
/// - Weekly: orderBy weeklyXp DESC, limit 20
/// - Daily: orderBy dailyXp DESC, limit 20
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
  Future<List<LeaderboardEntry>> fetch(LeaderboardTab tab, {bool forceRefresh = false}) async {
    if (!forceRefresh && !isStale(tab)) {
      final cached = getCached(tab);
      if (cached != null) return cached;
    }

    try {
      final query = _buildQuery(tab);
      final snapshot = await query.get();

      final entries = snapshot.docs
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

  // ── Private ──────────────────────────────────────────────────────────────

  Query<Map<String, dynamic>> _buildQuery(LeaderboardTab tab) {
    final collection = FirebaseFirestore.instance.collection('hunters');
    switch (tab) {
      case LeaderboardTab.overall:
        return collection
            .orderBy('level', descending: true)
            .orderBy('xp', descending: true)
            .limit(30);
      case LeaderboardTab.weekly:
        return collection
            .orderBy('weeklyXp', descending: true)
            .limit(20);
      case LeaderboardTab.daily:
        return collection
            .orderBy('dailyXp', descending: true)
            .limit(20);
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

  String _dataKey(LeaderboardTab tab) => 'data_${tab.name}';
  String _timestampKey(LeaderboardTab tab) => 'ts_${tab.name}';
}

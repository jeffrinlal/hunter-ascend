/// Constants for the Hive local caching layer.
library;

class CacheConstants {
  CacheConstants._();

  /// Increment this when a breaking schema change is made to any Hive model.
  /// On startup, if the stored version doesn't match, all data boxes are
  /// deleted and rebuilt from the next Firestore snapshot.
  static const int cacheVersion = 1;

  // ── Box names ──────────────────────────────────────────────────────────
  static const String metadataBox = 'metadataBox';
  static const String hunterBox = 'hunterBox';
  static const String weightBox = 'weightBox';
  static const String questBox = 'questBox';
  static const String leaderboardBox = 'leaderboardBox';

  // ── Metadata keys ──────────────────────────────────────────────────────
  static const String keyCacheVersion = 'cacheVersion';
  static const String keyLastSyncTimestamp = 'lastSyncTimestamp';
  static const String keyCachedUid = 'cachedUid';
}

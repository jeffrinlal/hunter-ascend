import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';

/// Initializes Hive, registers adapters, and handles cache versioning.
///
/// Call [initialize] once during app startup (before [runApp]).
class HiveInit {
  HiveInit._();

  /// Initializes Hive storage, registers all TypeAdapters, validates
  /// cache version, and opens required boxes.
  ///
  /// If the stored cache version doesn't match [CacheConstants.cacheVersion],
  /// all data boxes are deleted (schema has changed) and will be rebuilt
  /// from the next Firestore snapshot.
  static Future<void> initialize() async {
    await Hive.initFlutter();
    debugPrint('[HIVE] Hive.initFlutter() complete');

    // Register adapters (safe to call multiple times — Hive ignores duplicates).
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HunterDataAdapter());
    }

    // Open metadata box first to check version.
    final meta = await Hive.openBox(CacheConstants.metadataBox);
    final storedVersion =
        meta.get(CacheConstants.keyCacheVersion, defaultValue: 0) as int;

    if (storedVersion < CacheConstants.cacheVersion) {
      // Schema changed — invalidate all cached data.
      debugPrint('[HIVE] Cache version mismatch '
          '($storedVersion < ${CacheConstants.cacheVersion}). Clearing caches.');
      await _deleteDataBoxes();
      await meta.put(CacheConstants.keyCacheVersion, CacheConstants.cacheVersion);
    }

    // Open data boxes.
    await Hive.openBox<HunterData>(CacheConstants.hunterBox);

    // Update last sync timestamp.
    await meta.put(
      CacheConstants.keyLastSyncTimestamp,
      DateTime.now().millisecondsSinceEpoch,
    );

    debugPrint('[HIVE] Initialization complete (version: ${CacheConstants.cacheVersion})');
  }

  /// Clears all data boxes (called on logout or UID mismatch).
  /// Does NOT clear metadata box.
  static Future<void> clearAllData() async {
    final hunterBox = Hive.box<HunterData>(CacheConstants.hunterBox);
    await hunterBox.clear();

    final meta = Hive.box(CacheConstants.metadataBox);
    await meta.delete(CacheConstants.keyCachedUid);
  }

  /// Deletes data box files from disk (used during version migration).
  static Future<void> _deleteDataBoxes() async {
    try {
      if (Hive.isBoxOpen(CacheConstants.hunterBox)) {
        await Hive.box<HunterData>(CacheConstants.hunterBox).close();
      }
      await Hive.deleteBoxFromDisk(CacheConstants.hunterBox);
    } catch (e) {
      debugPrint('[HIVE] Failed to delete box — $e');
    }
  }
}

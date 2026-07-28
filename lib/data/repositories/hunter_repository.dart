import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';

/// Cache-first repository for the hunter document (`hunters/{uid}`).
///
/// ## Responsibilities
/// - Owns a single Firestore `.snapshots()` subscription (no duplicates).
/// - Exposes a `Stream<HunterData?>` that emits cached data first, then
///   live updates from Firestore.
/// - Writes every Firestore snapshot to Hive immediately (no debounce).
/// - Provides synchronous `getCached()` for instant UI rendering.
/// - Clears cache on logout.
///
/// ## Guarantees
/// - At most ONE Firestore listener exists at any time (de-duplicated).
/// - Calling `watch()` multiple times returns the same broadcast stream.
/// - Calling `dispose()` cancels the Firestore subscription.
/// - Firestore remains the single source of truth.
class HunterRepository {
  HunterRepository._();

  static final HunterRepository instance = HunterRepository._();

  /// The active Firestore subscription. Only one exists at a time.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _firestoreSub;

  /// The UID currently being listened to. Guards against duplicate listeners.
  String? _listeningUid;

  /// Internal StreamController that merges cached + live data into one stream.
  /// Broadcast so multiple widgets can listen without duplicating the source.
  StreamController<HunterData?>? _controller;

  /// Cached stream reference. Broadcast StreamController.stream creates a new
  /// object on every access — we store it once to ensure StreamBuilder always
  /// sees the same identity and never re-subscribes unnecessarily.
  Stream<HunterData?>? _cachedStream;

  /// The last emitted HunterData (kept in memory for synchronous access).
  HunterData? _lastEmitted;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns the cached [HunterData] synchronously from Hive.
  /// Returns `null` if no cache exists (first-ever launch or after clear).
  HunterData? getCached() {
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      final cached = box.get('current');
      if (cached != null) _lastEmitted = cached;
      return cached;
    } catch (e) {
      debugPrint('[HIVE] getCached ERROR: $e');
      return null;
    }
  }

  /// Stream of [HunterData] updates. Emits cached data first (if available),
  /// then live Firestore updates.
  ///
  /// Safe to call multiple times — returns the same broadcast stream and
  /// does not create duplicate Firestore listeners.
  Stream<HunterData?> watch() {
    _ensureListening();
    return _cachedStream!;
  }

  /// Clears the local cache and cancels the Firestore listener.
  /// Call on logout or account switch.
  Future<void> clearCache() async {
    _stopListening();
    _lastEmitted = null;
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      await box.clear();

      final meta = Hive.box(CacheConstants.metadataBox);
      await meta.delete(CacheConstants.keyCachedUid);
    } catch (e) {
      debugPrint('[HIVE] clearCache ERROR: $e');
    }
  }

  /// Stops the Firestore listener and closes the stream controller.
  /// Call when the repository is no longer needed (app shutdown).
  void dispose() {
    _stopListening();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  /// Ensures exactly one Firestore listener is active for the current user.
  /// Creates the broadcast StreamController on first call.
  void _ensureListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Already listening for this user — no-op.
    if (_firestoreSub != null && _listeningUid == uid && _controller != null) {
      return;
    }

    // Different user or first call — (re)start.
    _stopListening();
    _listeningUid = uid;

    _controller = StreamController<HunterData?>.broadcast();
    _cachedStream = _controller!.stream;

    // Validate UID matches cached data.
    _validateCachedUid(uid);

    // Start Firestore subscription.
    _firestoreSub = FirebaseFirestore.instance
        .collection('hunters')
        .doc(uid)
        .snapshots()
        .listen(
      (snapshot) => _onSnapshot(snapshot, uid),
      onError: (e) {
        debugPrint('[HIVE] Firestore listener ERROR: $e');
      },
    );
  }

  void _onSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot, String uid) {
    if (!snapshot.exists) return;
    final data = snapshot.data();
    if (data == null) return;

    var hunterData = HunterData.fromFirestore(data);

    // mealsLoggedCount / proteinGoalHitDays / balancedMacroDays /
    // lastProteinGoalHitDate / lastBalancedMacroDate are local-only —
    // never written to Firestore (see updateNutritionAchievementLocal).
    // Carry forward whatever is already cached so an unrelated Firestore
    // sync (XP gain, quest update, etc.) doesn't wipe them back to 0.
    final existing = _lastEmitted ?? getCached();
    if (existing != null) {
      hunterData = hunterData.copyWith(
        mealsLoggedCount: existing.mealsLoggedCount,
        proteinGoalHitDays: existing.proteinGoalHitDays,
        lastProteinGoalHitDate: existing.lastProteinGoalHitDate,
        balancedMacroDays: existing.balancedMacroDays,
        lastBalancedMacroDate: existing.lastBalancedMacroDate,
      );
    }

    _lastEmitted = hunterData;

    // Write to Hive (immediate, no debounce).
    _writeToCache(hunterData, uid);

    // Emit to stream.
    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(hunterData);
    }
  }

  /// Updates ONLY the local-only nutrition achievement tracking fields
  /// (mealsLoggedCount, proteinGoalHitDays, balancedMacroDays, and their
  /// last-hit dates) directly in the Hive cache and emits the change to
  /// the stream. These fields are never written to Firestore — nothing
  /// outside this device reads them (no leaderboard/public-profile/other
  /// user ever sees them), so there's no need to round-trip them through
  /// `hunters/{uid}`. Caller supplies already-computed totals; this method
  /// does no Firestore reads or writes.
  void updateNutritionAchievementLocal({
    required bool incrementMealsLogged,
    required bool hitProteinGoalToday,
    required bool hitBalancedToday,
    required String today,
  }) {
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      final current = box.get('current') ?? _lastEmitted;
      if (current == null) return;

      final newMealsCount = incrementMealsLogged
          ? current.mealsLoggedCount + 1
          : current.mealsLoggedCount;

      var newProteinDays = current.proteinGoalHitDays;
      var newProteinDate = current.lastProteinGoalHitDate;
      if (hitProteinGoalToday && current.lastProteinGoalHitDate != today) {
        newProteinDays += 1;
        newProteinDate = today;
      }

      var newBalancedDays = current.balancedMacroDays;
      var newBalancedDate = current.lastBalancedMacroDate;
      if (hitBalancedToday && current.lastBalancedMacroDate != today) {
        newBalancedDays += 1;
        newBalancedDate = today;
      }

      final updated = current.copyWith(
        mealsLoggedCount: newMealsCount,
        proteinGoalHitDays: newProteinDays,
        lastProteinGoalHitDate: newProteinDate,
        balancedMacroDays: newBalancedDays,
        lastBalancedMacroDate: newBalancedDate,
      );

      box.put('current', updated);
      _lastEmitted = updated;

      if (_controller != null && !_controller!.isClosed) {
        _controller!.add(updated);
      }
    } catch (e) {
      debugPrint('[HIVE] updateNutritionAchievementLocal ERROR: $e');
    }
  }

  /// Writes [HunterData] to the local Hive cache.
  void _writeToCache(HunterData hunterData, String uid) {
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      box.put('current', hunterData);
      final meta = Hive.box(CacheConstants.metadataBox);
      meta.put(CacheConstants.keyCachedUid, uid);
      meta.put(CacheConstants.keyLastSyncTimestamp,
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[HIVE] _writeToCache ERROR: $e');
    }
  }

  /// If the cached UID doesn't match the current user, clears stale data.
  void _validateCachedUid(String currentUid) {
    try {
      final meta = Hive.box(CacheConstants.metadataBox);
      final cachedUid = meta.get(CacheConstants.keyCachedUid) as String?;
      if (cachedUid != null && cachedUid != currentUid) {
        final box = Hive.box<HunterData>(CacheConstants.hunterBox);
        box.clear();
        meta.delete(CacheConstants.keyCachedUid);
        _lastEmitted = null;
      }
    } catch (e) {
      debugPrint('[HIVE] _validateCachedUid ERROR: $e');
    }
  }

  void _stopListening() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _listeningUid = null;
    _controller?.close();
    _controller = null;
    _cachedStream = null;
  }
}

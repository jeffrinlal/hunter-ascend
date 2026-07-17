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
      debugPrint('HunterRepository.getCached: $e');
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
    return _controller!.stream;
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
      debugPrint('HunterRepository.clearCache: $e');
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

    _controller = StreamController<HunterData?>.broadcast(
      onListen: () {
        // Emit cached data immediately when the first listener attaches.
        final cached = getCached();
        if (cached != null && _controller != null && !_controller!.isClosed) {
          _controller!.add(cached);
        }
      },
    );

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
        debugPrint('HunterRepository: Firestore listener error — $e');
      },
    );
  }

  /// Handles each Firestore snapshot: converts to domain model, caches,
  /// and emits to the stream.
  void _onSnapshot(
      DocumentSnapshot<Map<String, dynamic>> snapshot, String uid) {
    if (!snapshot.exists) return;
    final data = snapshot.data();
    if (data == null) return;

    final hunterData = HunterData.fromFirestore(data);
    _lastEmitted = hunterData;

    // Write to Hive (immediate, no debounce).
    _writeToCache(hunterData, uid);

    // Emit to stream.
    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(hunterData);
    }
  }

  /// Writes [HunterData] to the local Hive cache.
  void _writeToCache(HunterData hunterData, String uid) {
    try {
      final box = Hive.box<HunterData>(CacheConstants.hunterBox);
      box.put('current', hunterData);

      // Record which UID this cache belongs to.
      final meta = Hive.box(CacheConstants.metadataBox);
      meta.put(CacheConstants.keyCachedUid, uid);
      meta.put(CacheConstants.keyLastSyncTimestamp,
          DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('HunterRepository._writeToCache: $e');
    }
  }

  /// If the cached UID doesn't match the current user, clears stale data.
  void _validateCachedUid(String currentUid) {
    try {
      final meta = Hive.box(CacheConstants.metadataBox);
      final cachedUid = meta.get(CacheConstants.keyCachedUid) as String?;
      if (cachedUid != null && cachedUid != currentUid) {
        debugPrint('HunterRepository: UID mismatch — clearing stale cache.');
        final box = Hive.box<HunterData>(CacheConstants.hunterBox);
        box.clear();
        meta.delete(CacheConstants.keyCachedUid);
        _lastEmitted = null;
      }
    } catch (e) {
      debugPrint('HunterRepository._validateCachedUid: $e');
    }
  }

  /// Cancels the Firestore subscription and closes the stream controller.
  void _stopListening() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _listeningUid = null;
    _controller?.close();
    _controller = null;
  }
}

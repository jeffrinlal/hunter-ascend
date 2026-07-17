import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/weight_entry.dart';

/// Cache-first repository for weight history (`weight_history` collection).
///
/// ## Responsibilities
/// - Owns a single Firestore `.snapshots()` subscription on weight_history.
/// - Caches entries to Hive for instant loading on next app open.
/// - Exposes `Stream<List<WeightEntry>>` via `watch()`.
/// - Provides `getCached()` for synchronous first-frame data.
/// - Provides `latest()` for the most recent weight entry.
///
/// ## Guarantees
/// - At most ONE Firestore listener exists at any time (de-duplicated).
/// - Data layer only — no business logic (BMI calc, goal tracking, etc.).
/// - Firestore remains the single source of truth.
class WeightRepository {
  WeightRepository._();

  static final WeightRepository instance = WeightRepository._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  String? _listeningUid;
  StreamController<List<WeightEntry>>? _controller;
  Stream<List<WeightEntry>>? _cachedStream;
  List<WeightEntry>? _lastEmitted;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns cached weight entries synchronously from Hive.
  /// Returns empty list if no cache exists.
  List<WeightEntry> getCached() {
    try {
      final box = Hive.box<List>(CacheConstants.weightBox);
      final raw = box.get('entries');
      if (raw == null) return [];
      final entries = raw.cast<WeightEntry>();
      _lastEmitted = entries;
      return entries;
    } catch (e) {
      debugPrint('[HIVE] WeightRepository.getCached ERROR: $e');
      return [];
    }
  }

  /// Returns the most recent weight entry, or null if none cached.
  WeightEntry? latest() {
    final entries = _lastEmitted ?? getCached();
    if (entries.isEmpty) return null;
    return entries.first; // ordered by date desc
  }

  /// Stream of weight history updates. Sorted by date descending.
  /// Safe to call multiple times — returns the same broadcast stream.
  Stream<List<WeightEntry>> watch() {
    _ensureListening();
    return _cachedStream!;
  }

  /// Clears the local cache and cancels the Firestore listener.
  Future<void> clearCache() async {
    _stopListening();
    _lastEmitted = null;
    try {
      final box = Hive.box<List>(CacheConstants.weightBox);
      await box.clear();
    } catch (e) {
      debugPrint('[HIVE] WeightRepository.clearCache ERROR: $e');
    }
  }

  void dispose() {
    _stopListening();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  void _ensureListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_firestoreSub != null && _listeningUid == uid && _controller != null) {
      return;
    }

    _stopListening();
    _listeningUid = uid;

    _controller = StreamController<List<WeightEntry>>.broadcast();
    _cachedStream = _controller!.stream;

    _firestoreSub = FirebaseFirestore.instance
        .collection('weight_history')
        .where('uid', isEqualTo: uid)
        .orderBy('date', descending: true)
        .snapshots()
        .listen(
      (snapshot) => _onSnapshot(snapshot),
      onError: (e) {
        debugPrint('[HIVE] WeightRepository Firestore error: $e');
      },
    );
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final entries = snapshot.docs
        .map((doc) => WeightEntry.fromFirestore(doc.data()))
        .toList();

    _lastEmitted = entries;
    _writeToCache(entries);

    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(entries);
    }
  }

  void _writeToCache(List<WeightEntry> entries) {
    try {
      final box = Hive.box<List>(CacheConstants.weightBox);
      box.put('entries', entries);
    } catch (e) {
      debugPrint('[HIVE] WeightRepository._writeToCache ERROR: $e');
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

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';
import 'package:hunter_ascend/data/models/custom_quest.dart';

/// Cache-first repository for custom quests (`custom_quests` collection).
///
/// ## Responsibilities
/// - Owns a single Firestore `.snapshots()` subscription on custom_quests.
/// - Caches entries to Hive for instant loading on next app open.
/// - Exposes `Stream<List<CustomQuest>>` via `watch()`.
/// - Provides `getCached()` for synchronous first-frame data.
///
/// ## Guarantees
/// - At most ONE Firestore listener at any time (de-duplicated).
/// - Data layer only — no quest logic, no generation, no timers.
/// - Firestore remains the single source of truth.
class QuestRepository {
  QuestRepository._();

  static final QuestRepository instance = QuestRepository._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  String? _listeningUid;
  StreamController<List<CustomQuest>>? _controller;
  Stream<List<CustomQuest>>? _cachedStream;
  List<CustomQuest>? _lastEmitted;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns cached custom quests synchronously from Hive.
  /// Returns empty list if no cache exists.
  List<CustomQuest> getCached() {
    try {
      final box = Hive.box<List>(CacheConstants.questBox);
      final raw = box.get('entries');
      if (raw == null) return [];
      final entries = raw.cast<CustomQuest>();
      _lastEmitted = entries;
      return entries;
    } catch (e) {
      debugPrint('[HIVE] QuestRepository.getCached ERROR: $e');
      return [];
    }
  }

  /// Stream of custom quest updates.
  /// Safe to call multiple times — returns the same broadcast stream.
  Stream<List<CustomQuest>> watch() {
    _ensureListening();
    return _cachedStream!;
  }

  /// Clears the local cache and cancels the Firestore listener.
  Future<void> clearCache() async {
    _stopListening();
    _lastEmitted = null;
    try {
      final box = Hive.box<List>(CacheConstants.questBox);
      await box.clear();
    } catch (e) {
      debugPrint('[HIVE] QuestRepository.clearCache ERROR: $e');
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

    _controller = StreamController<List<CustomQuest>>.broadcast();
    _cachedStream = _controller!.stream;

    _firestoreSub = FirebaseFirestore.instance
        .collection('custom_quests')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .listen(
      (snapshot) => _onSnapshot(snapshot),
      onError: (e) {
        debugPrint('[HIVE] QuestRepository Firestore error: $e');
      },
    );
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    final entries = snapshot.docs
        .map((doc) => CustomQuest.fromFirestore(doc))
        .toList();

    _lastEmitted = entries;
    _writeToCache(entries);

    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(entries);
    }
  }

  void _writeToCache(List<CustomQuest> entries) {
    try {
      final box = Hive.box<List>(CacheConstants.questBox);
      box.put('entries', entries);
    } catch (e) {
      debugPrint('[HIVE] QuestRepository._writeToCache ERROR: $e');
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

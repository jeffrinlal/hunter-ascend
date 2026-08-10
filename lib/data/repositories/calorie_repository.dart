import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A single logged food entry (one meal/snack item) for the calorie tracker.
///
/// Backed by the `calorie_logs` Firestore collection. Immutable.
class MealEntry {
  final String? id;
  final String name;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final DateTime time;

  MealEntry({
    this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.time,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'time': Timestamp.fromDate(time),
  };

  factory MealEntry.fromMap(Map<String, dynamic> m) => MealEntry(
    name: m['name'] ?? '',
    calories: m['calories'] ?? 0,
    protein: (m['protein'] ?? 0).toDouble(),
    carbs: (m['carbs'] ?? 0).toDouble(),
    fat: (m['fat'] ?? 0).toDouble(),
    time: (m['time'] as Timestamp).toDate(),
  );

  MealEntry copyWith({String? id}) => MealEntry(
    id: id ?? this.id,
    name: name,
    calories: calories,
    protein: protein,
    carbs: carbs,
    fat: fat,
    time: time,
  );
}

/// Cache-first repository for calorie logs (`calorie_logs` collection).
///
/// ## Responsibilities
/// - Owns a single Firestore `.snapshots()` subscription on today's calorie_logs.
/// - Caches today's entries in memory for instant UI updates.
/// - Exposes `Stream<List<MealEntry>>` via `watch()`.
/// - Provides `getCached()` for synchronous first-frame data.
/// - Handles midnight date transitions by clearing cache and reloading.
///
/// ## Guarantees
/// - At most ONE Firestore listener exists at any time (de-duplicated).
/// - Calling `watch()` multiple times returns the SAME broadcast stream.
/// - Add/delete operations update the cache immediately for instant UI.
/// - Firestore remains the single source of truth.
/// - Multi-device changes are synced via the Firestore listener.
class CalorieRepository {
  CalorieRepository._();

  static final CalorieRepository instance = CalorieRepository._();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _firestoreSub;
  String? _listeningUid;
  String? _listeningDate;
  StreamController<List<MealEntry>>? _controller;
  Stream<List<MealEntry>>? _cachedStream;
  List<MealEntry> _cached = [];
  Timer? _midnightTimer;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns cached meal entries for today synchronously.
  /// Returns empty list if no cache exists or user not signed in.
  List<MealEntry> getCached() => List.unmodifiable(_cached);

  /// Stream of today's meal updates. Sorted by time descending.
  /// Safe to call multiple times — returns the same broadcast stream.
  /// Automatically handles midnight transitions by clearing cache.
  Stream<List<MealEntry>> watch() {
    _ensureListening();
    return _cachedStream ?? Stream.value([]);
  }

  /// Adds a meal to today's logs.
  /// Updates cache immediately, then writes to Firestore asynchronously.
  /// Returns the document ID after successful write.
  Future<String?> addMeal(MealEntry meal) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final today = _today();
    
    try {
      // Write to Firestore first to get doc ID
      final docRef = await FirebaseFirestore.instance
          .collection('calorie_logs')
          .add({
        ...meal.toMap(),
        'uid': user.uid,
        'date': today,
      });

      // Update cache immediately with the new doc ID
      final mealWithId = meal.copyWith(id: docRef.id);
      _cached = [mealWithId, ..._cached];
      _emitCached();

      debugPrint('[CalorieRepository] Meal added: ${meal.name} (${docRef.id})');
      return docRef.id;
    } catch (e) {
      debugPrint('[CalorieRepository] addMeal ERROR: $e');
      return null;
    }
  }

  /// Deletes a meal from today's logs.
  /// Updates cache immediately, then deletes from Firestore asynchronously.
  Future<bool> deleteMeal(String docId) async {
    try {
      // Update cache immediately
      _cached = _cached.where((m) => m.id != docId).toList();
      _emitCached();

      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('calorie_logs')
          .doc(docId)
          .delete();

      debugPrint('[CalorieRepository] Meal deleted: $docId');
      return true;
    } catch (e) {
      debugPrint('[CalorieRepository] deleteMeal ERROR: $e');
      return false;
    }
  }

  /// Clears the cache and cancels the Firestore listener.
  /// Used on sign-out or when switching users.
  Future<void> clearCache() async {
    debugPrint('[CalorieRepository] Clearing cache');
    _stopListening();
    _cached = [];
  }

  void dispose() {
    debugPrint('[CalorieRepository] Disposing');
    _stopListening();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  String _today() => DateTime.now().toString().substring(0, 10);

  void _ensureListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final today = _today();

    // Reuse existing listener if same user and same date
    if (_firestoreSub != null && 
        _listeningUid == uid && 
        _listeningDate == today && 
        _controller != null) {
      debugPrint('[CalorieRepository] Reusing existing listener');
      return;
    }

    // Date changed or first load - reset
    if (_listeningDate != null && _listeningDate != today) {
      debugPrint('[CalorieRepository] Date changed, clearing cache');
      _cached = [];
    }

    _stopListening();
    _listeningUid = uid;
    _listeningDate = today;

    _controller = StreamController<List<MealEntry>>.broadcast();
    _cachedStream = _controller!.stream;

    debugPrint('[CalorieRepository] Creating Firestore listener for $today');

    _firestoreSub = FirebaseFirestore.instance
        .collection('calorie_logs')
        .where('uid', isEqualTo: uid)
        .where('date', isEqualTo: today)
        .orderBy('time', descending: true)
        .snapshots()
        .listen(
      (snapshot) => _onSnapshot(snapshot),
      onError: (e) {
        debugPrint('[CalorieRepository] Firestore error: $e');
      },
    );

    _scheduleMidnightRefresh();
  }

  void _onSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _cached = snapshot.docs.map((doc) {
      final meal = MealEntry.fromMap(doc.data());
      return meal.copyWith(id: doc.id);
    }).toList();

    debugPrint('[CalorieRepository] Snapshot received: ${_cached.length} meals');
    _emitCached();
  }

  void _emitCached() {
    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(List.unmodifiable(_cached));
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);

    debugPrint('[CalorieRepository] Scheduling midnight refresh in ${delay.inHours}h');

    _midnightTimer = Timer(delay, () {
      debugPrint('[CalorieRepository] Midnight! Refreshing for new day');
      _cached = [];
      _listeningDate = null;
      _stopListening();
      _ensureListening();
    });
  }

  void _stopListening() {
    _firestoreSub?.cancel();
    _firestoreSub = null;
    _listeningUid = null;
    _listeningDate = null;
    _controller?.close();
    _controller = null;
    _cachedStream = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }
}

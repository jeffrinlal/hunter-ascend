import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:hunter_ascend/data/cache_constants.dart';

/// A single logged food entry (one meal/snack item) for the calorie tracker.
///
/// Previously backed by the `calorie_logs` Firestore collection; now persisted
/// locally via Hive for today only. The data model is unchanged so all UI code
/// continues to work without modification.
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

  /// Serializes to a plain JSON-compatible map for Hive storage (no Firestore
  /// Timestamp — uses millisecondsSinceEpoch instead).
  Map<String, dynamic> _toHiveMap() => {
    'id': id,
    'name': name,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
    'timeMs': time.millisecondsSinceEpoch,
  };

  /// Deserializes from the Hive-stored plain map.
  factory MealEntry._fromHiveMap(Map m) => MealEntry(
    id: m['id'] as String?,
    name: (m['name'] ?? '') as String,
    calories: (m['calories'] ?? 0) as int,
    protein: ((m['protein'] ?? 0) as num).toDouble(),
    carbs: ((m['carbs'] ?? 0) as num).toDouble(),
    fat: ((m['fat'] ?? 0) as num).toDouble(),
    time: DateTime.fromMillisecondsSinceEpoch((m['timeMs'] ?? 0) as int),
  );
}

/// Local-only repository for calorie logs — persisted via Hive for today only.
///
/// ## Design
/// Today's meals survive app kills, background cleanup, and phone restarts
/// (Hive writes to disk immediately). Previous days' data is auto-cleared on
/// first access after midnight — no permanent history is retained.
///
/// ## What was removed vs Firestore
/// - 1 permanent Firestore listener (−1, total now 21)
/// - 1 write per meal logged
/// - 1 delete per meal removed
/// - 1 historical query in ReportService
/// - 1 batch-delete in AccountDeletionService
///
/// ## API contract (unchanged)
/// - `watch()` → `Stream<List<MealEntry>>` (broadcast)
/// - `getCached()` → today's meals synchronously
/// - `addMeal()` → returns generated ID
/// - `deleteMeal()` → removes by ID
/// - `clearCache()` → resets on sign-out
class CalorieRepository {
  CalorieRepository._();

  static final CalorieRepository instance = CalorieRepository._();

  static const String _keyMeals = 'meals_today';
  static const String _keyDate = 'meals_date';

  StreamController<List<MealEntry>>? _controller;
  Stream<List<MealEntry>>? _cachedStream;
  List<MealEntry> _cached = [];
  Timer? _midnightTimer;
  int _nextId = 1;

  // ── Public API ───────────────────────────────────────────────────────────

  /// Returns cached meal entries for today synchronously.
  List<MealEntry> getCached() {
    _loadFromHiveIfNeeded();
    return List.unmodifiable(_cached);
  }

  /// Stream of today's meal updates. Sorted by time descending.
  /// Safe to call multiple times — returns the same broadcast stream.
  Stream<List<MealEntry>> watch() {
    _ensureReady();
    return _cachedStream ?? Stream.value([]);
  }

  /// Adds a meal to today's logs. Persisted to Hive immediately.
  Future<String?> addMeal(MealEntry meal) async {
    _ensureReady();

    final id = 'local_${_nextId++}';
    final mealWithId = meal.copyWith(id: id);
    _cached = [mealWithId, ..._cached];
    _persistToHive();
    _emit();

    debugPrint('[CalorieRepository] Meal added: ${meal.name} ($id)');
    return id;
  }

  /// Deletes a meal from today's logs. Persisted to Hive immediately.
  Future<bool> deleteMeal(String docId) async {
    final before = _cached.length;
    _cached = _cached.where((m) => m.id != docId).toList();
    if (_cached.length < before) {
      _persistToHive();
      _emit();
      debugPrint('[CalorieRepository] Meal deleted: $docId');
      return true;
    }
    return false;
  }

  /// Clears the cache. Used on sign-out or user switch.
  Future<void> clearCache() async {
    debugPrint('[CalorieRepository] Clearing cache');
    _cached = [];
    _nextId = 1;
    try {
      final box = Hive.box(CacheConstants.calorieBox);
      await box.clear();
    } catch (e) {
      debugPrint('[CalorieRepository] clearCache Hive: $e');
    }
    _controller?.close();
    _controller = null;
    _cachedStream = null;
    _midnightTimer?.cancel();
    _midnightTimer = null;
  }

  void dispose() {
    clearCache();
  }

  // ── Private ──────────────────────────────────────────────────────────────

  static String _today() => DateTime.now().toString().substring(0, 10);

  bool _loaded = false;

  void _loadFromHiveIfNeeded() {
    if (_loaded) return;
    _loaded = true;
    try {
      final box = Hive.box(CacheConstants.calorieBox);
      final storedDate = box.get(_keyDate) as String?;
      final today = _today();

      if (storedDate != today) {
        // Previous day's data — discard silently.
        box.clear();
        _cached = [];
        _nextId = 1;
        return;
      }

      final stored = box.get(_keyMeals);
      if (stored is List) {
        _cached = stored
            .whereType<Map>()
            .map((m) => MealEntry._fromHiveMap(m))
            .toList();
        // Restore next ID counter past all existing IDs.
        for (final meal in _cached) {
          final idStr = meal.id ?? '';
          if (idStr.startsWith('local_')) {
            final num = int.tryParse(idStr.substring(6)) ?? 0;
            if (num >= _nextId) _nextId = num + 1;
          }
        }
      }
    } catch (e) {
      debugPrint('[CalorieRepository] _loadFromHiveIfNeeded: $e');
      _cached = [];
    }
  }

  void _ensureReady() {
    _loadFromHiveIfNeeded();

    // Check if date rolled over since last access.
    final today = _today();
    try {
      final box = Hive.box(CacheConstants.calorieBox);
      final storedDate = box.get(_keyDate) as String?;
      if (storedDate != null && storedDate != today) {
        debugPrint('[CalorieRepository] New day detected, clearing');
        box.clear();
        _cached = [];
        _nextId = 1;
      }
    } catch (_) {}

    if (_controller == null || _controller!.isClosed) {
      _controller = StreamController<List<MealEntry>>.broadcast();
      _cachedStream = _controller!.stream;
    }

    _scheduleMidnightRefresh();
  }

  void _persistToHive() {
    try {
      final box = Hive.box(CacheConstants.calorieBox);
      box.put(_keyDate, _today());
      box.put(_keyMeals, _cached.map((m) => m._toHiveMap()).toList());
    } catch (e) {
      debugPrint('[CalorieRepository] _persistToHive: $e');
    }
  }

  void _emit() {
    if (_controller != null && !_controller!.isClosed) {
      _controller!.add(List.unmodifiable(_cached));
    }
  }

  void _scheduleMidnightRefresh() {
    if (_midnightTimer != null) return;
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now);

    _midnightTimer = Timer(delay, () {
      debugPrint('[CalorieRepository] Midnight — clearing for new day');
      _cached = [];
      _nextId = 1;
      _loaded = false;
      _midnightTimer = null;
      try {
        Hive.box(CacheConstants.calorieBox).clear();
      } catch (_) {}
      _emit();
    });
  }
}

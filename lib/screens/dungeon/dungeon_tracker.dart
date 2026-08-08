import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:pedometer/pedometer.dart';

/// Objective TYPE → existing fitness data. This is the ONLY place that
/// knows which source feeds which objective type — no text or title is
/// ever interpreted:
///
/// * `steps`            → device pedometer (`Pedometer.stepCountStream`),
/// * `water`            → the hunter's shared daily water intake
///                        (`HunterRepository.watch()`),
/// * `walking_distance` → GPS distance of runs saved today (`runs`),
/// * `running_distance` → GPS distance of runs saved today (`runs`) —
///                        the run tracker records distance without a
///                        walk/run label, so both observe the same source,
/// * `calories`         → calories burned by runs saved today (`runs`).
///
/// Every source is OBSERVED, never written: the tracker reuses the app's
/// existing fitness data exactly as the dashboard, nutrition and map
/// screens do.
///
/// SNAPSHOT architecture: the tracker is a pure CURRENT-VALUE emitter —
/// it holds NO baselines and computes NO deltas. It reports the source's
/// live value to `DungeonSessionManager`, which derives progress against
/// the session's fixed `startValue` snapshots. One-shot reads
/// ([currentStepTotal], [todayRunTotals], [currentWaterMl]) let the
/// manager capture those snapshots once at session start.
class DungeonTracker {
  DungeonTracker({
    required void Function(DungeonObjectiveType type, double currentValue)
        onValue,
  }) : _onValue = onValue;

  /// Live readings: (objective type, CURRENT hunter value for that
  /// source). The manager turns these into snapshot-based progress.
  final void Function(DungeonObjectiveType type, double currentValue)
      _onValue;

  StreamSubscription<StepCount>? _stepSub;
  StreamSubscription<dynamic>? _waterSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _runsSub;

  /// Starts observing every source. Owned by `DungeonSessionManager` —
  /// its lifetime is the DUNGEON SESSION's, never a widget's.
  void start() {
    _watchSteps();
    _watchWater();
    _watchRuns();
  }

  void dispose() {
    _stepSub?.cancel();
    _waterSub?.cancel();
    _runsSub?.cancel();
    _stepSub = null;
    _waterSub = null;
    _runsSub = null;
  }

  // ── Live sources ─────────────────────────────────────────────────────

  /// Steps — the raw device counter. The session snapshot pins the value
  /// at dungeon start; only the DIFFERENCE to it matters.
  void _watchSteps() {
    _stepSub = Pedometer.stepCountStream.listen(
      (event) =>
          _onValue(DungeonObjectiveType.steps, event.steps.toDouble()),
      onError: (Object e) => debugPrint('[DungeonTracker] pedometer: $e'),
    );
  }

  /// Water — the shared daily intake (0 on a new day). Logging a cup on
  /// the dashboard/nutrition tab is the very value the dungeon reads.
  void _watchWater() {
    _waterSub = HunterRepository.instance.watch().listen((hunter) {
      _onValue(DungeonObjectiveType.water, currentWaterMl(hunter).toDouble());
    });
  }

  /// Runs saved today (`runs` collection — the SAME query shape the map
  /// screen already uses, so no new index). Distance feeds walking AND
  /// running objectives; burned calories feed calories objectives.
  void _watchRuns() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _runsSub = _todayRunsQuery(uid).snapshots().listen(
      (snapshot) {
        final totals = _sumToday(snapshot);
        _onValue(DungeonObjectiveType.walkingDistance, totals.distance);
        _onValue(DungeonObjectiveType.runningDistance, totals.distance);
        _onValue(DungeonObjectiveType.calories, totals.calories);
      },
      onError: (Object e) => debugPrint('[DungeonTracker] runs: $e'),
    );
  }

  // ── One-shot snapshot capture (session start) ────────────────────────

  /// Current daily water intake for a hunter payload — shared by the
  /// live watcher and the manager's snapshot capture.
  static int currentWaterMl(dynamic hunter) =>
      (hunter != null && hunter.waterIntakeDate == DungeonDailyStore.today)
          ? hunter.waterIntakeMl as int
          : 0;

  /// One pedometer reading for the snapshot capture. The stream emits the
  /// current cumulative count almost immediately on listen; the timeout
  /// covers permission-denied / sensor-unavailable so entry never hangs.
  /// Null → the manager captures the snapshot on the first live reading.
  static Future<double?> currentStepTotal({
    Duration timeout = const Duration(seconds: 3),
  }) {
    final completer = Completer<double?>();
    late StreamSubscription<StepCount> sub;
    void finish(double? value) {
      if (completer.isCompleted) return;
      completer.complete(value);
      sub.cancel();
    }

    sub = Pedometer.stepCountStream.listen(
      (event) => finish(event.steps.toDouble()),
      onError: (Object _) => finish(null),
    );
    Future<void>.delayed(timeout, () => finish(null));
    return completer.future;
  }

  /// Today's saved-run totals (distance km, burned calories) for the
  /// snapshot capture — one-shot `get()` with the same query shape the
  /// live watcher uses.
  static Future<(double distance, double calories)> todayRunTotals() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (0.0, 0.0);
    try {
      final snapshot = await _todayRunsQuery(uid).get();
      final totals = _sumToday(snapshot);
      return (totals.distance, totals.calories);
    } catch (e) {
      debugPrint('[DungeonTracker] runs capture: $e');
      return (0.0, 0.0);
    }
  }

  // ── Shared query helpers ─────────────────────────────────────────────

  static Query<Map<String, dynamic>> _todayRunsQuery(String uid) =>
      FirebaseFirestore.instance
          .collection('runs')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(10);

  static ({double distance, double calories}) _sumToday(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    double distance = 0;
    double calories = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final created = (data['createdAt'] as Timestamp?)?.toDate();
      if (created == null ||
          created.toString().substring(0, 10) != DungeonDailyStore.today) {
        continue;
      }
      distance += ((data['distanceKm'] ?? 0) as num).toDouble();
      calories += ((data['caloriesBurned'] ?? 0) as num).toDouble();
    }
    return (distance: distance, calories: calories);
  }
}

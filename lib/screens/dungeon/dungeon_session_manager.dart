import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_tracker.dart';

/// Lifecycle of today's dungeon session.
enum DungeonSessionStatus { active, cleared }

/// One persistent dungeon run. Created when the hunter presses ENTER
/// DUNGEON and alive until the dungeon is cleared or the day resets —
/// NEVER tied to a screen: closing the play screen, navigating home or
/// restarting the app leaves the session untouched.
class DungeonSession {
  DungeonSession({
    required this.gateLetter,
    required this.day,
    required this.monsters,
    required this.boss,
    required this.story,
    required this.startedAt,
    this.status = DungeonSessionStatus.active,
  });

  final String gateLetter;

  /// Calendar day the session belongs to — the daily-reset guard.
  final String day;

  final List<DungeonObjective> monsters;
  final DungeonObjective boss;
  final String story;

  /// When the session started (snapshot capture).
  final DateTime startedAt;

  DungeonSessionStatus status;

  bool get isCleared => status == DungeonSessionStatus.cleared;

  bool get bossUnlocked =>
      monsters.isNotEmpty && monsters.every((m) => m.isComplete);

  Iterable<DungeonObjective> get allObjectives sync* {
    yield* monsters;
    yield boss;
  }
}

/// Persistent Dungeon Session owner — the single place where the dungeon
/// run lives. Responsibilities: the current active dungeon, objective
/// progress, tracker lifecycle, completion state and listeners.
///
/// Architecture contract (replaces the old screen-owned tracker):
///
/// * The play screen is a VIEWER. It reads this manager and listens — it
///   never owns tracking, baselines or persistence.
/// * The [DungeonTracker] belongs to the SESSION, not to any widget: it
///   keeps running while the player is on the dashboard, leaderboard or
///   profile, and only stops when the dungeon is cleared.
/// * Progress uses SNAPSHOT semantics: each objective's
///   [DungeonObjective.startValue] is captured ONCE at session start and
///   stays fixed; progress = currentHunterValue − startValue. Nothing is
///   ever re-baselined, so activity performed anywhere in the app counts
///   and re-entry/restart never resets nor double-counts.
/// * Persistence reuses [DungeonDailyStore] — app restart restores
///   objectives, snapshots, monster HP and completion state without
///   regenerating.
class DungeonSessionManager extends ChangeNotifier {
  DungeonSessionManager._();

  static final DungeonSessionManager instance = DungeonSessionManager._();

  DungeonSession? _session;
  DungeonTracker? _tracker;

  /// Serializes enter/restore so double taps and route rebuilds cannot
  /// race into two sessions.
  Future<void>? _opening;

  // ── View API (the play screen reads ONLY these) ──────────────────────

  DungeonSession? get session => _session;
  bool get hasSession => _session != null;
  List<DungeonObjective> get monsters => _session?.monsters ?? const [];
  DungeonObjective? get boss => _session?.boss;
  String get story => _session?.story ?? '';
  bool get bossUnlocked => _session?.bossUnlocked ?? false;
  bool get isCleared => _session?.isCleared ?? false;

  // ── Entry (ENTER DUNGEON press on the gate screen) ───────────────────

  /// Creates/restores today's session for [gate]. AI generation runs
  /// exactly once per day HERE — afterwards the daily store serves the
  /// same dungeon until completion or the daily reset. Immediately after
  /// the dungeon exists, snapshots are captured ONCE and tracking starts.
  Future<void> enterDungeon({required DungeonGateSpec gate}) async {
    final letter = gate.letter;
    final existing =
        (await DungeonDailyStore.load(letter)).objectivesForToday();
    if (existing == null) {
      final generated =
          await DungeonGeneration.generateERankDungeon(gate: gate);
      await DungeonDailyStore.saveObjectives(letter, generated);
    }
    await openSession(letter: letter);
  }

  /// Restores today's session from the daily store (app restart, direct
  /// navigation) — idempotent: a live session for the same gate and day
  /// is reused as-is, never rebuilt.
  Future<void> openSession({required String letter}) {
    return _opening ??=
        _openSession(letter).whenComplete(() => _opening = null);
  }

  Future<void> _openSession(String letter) async {
    final existing = _session;
    if (existing != null &&
        existing.gateLetter == letter &&
        existing.day == DungeonDailyStore.today) {
      _syncTracking();
      return;
    }

    await DungeonDailyStore.markPlayed(letter);

    final state = await DungeonDailyStore.load(letter);
    var monsters = state.objectivesForToday();
    var boss = state.bossForToday();
    var story = state.storyForToday();

    if (monsters == null) {
      // Defensive only (e.g. cleared app data) — the local fallback costs
      // NO AI request and is saved so today reuses it like any dungeon.
      final fallback = DungeonGeneration.fallbackDungeon();
      await DungeonDailyStore.saveObjectives(letter, fallback);
      monsters = fallback.monsters;
      boss ??= fallback.boss;
      story = fallback.story;
    }

    // Dungeons persisted before the boss system existed get the fallback
    // boss — the run stays clearable without regenerating.
    boss ??= DungeonGeneration.fallbackBoss();

    final session = DungeonSession(
      gateLetter: letter,
      day: DungeonDailyStore.today,
      monsters: monsters,
      boss: boss,
      story: story,
      startedAt: state.sessionStartedAt ?? DateTime.now(),
      status: state.completedToday
          ? DungeonSessionStatus.cleared
          : DungeonSessionStatus.active,
    );
    _session = session;

    await _captureSnapshots(session);
    _syncTracking();
    notifyListeners();
  }

  // ── Snapshots (captured ONCE, fixed until the dungeon ends) ──────────

  /// Captures the current hunter values for every objective that still
  /// lacks a snapshot. Rows restored from a previous capture keep their
  /// fixed values — this method NEVER re-anchors an existing snapshot.
  Future<void> _captureSnapshots(DungeonSession session) async {
    final pending = session.allObjectives
        .where((o) => o.startValue == null)
        .toList();
    if (pending.isEmpty) return;

    final hunter = HunterRepository.instance.getCached();
    final water = DungeonTracker.currentWaterMl(hunter).toDouble();
    final (distance, calories) = await DungeonTracker.todayRunTotals();
    final steps = await DungeonTracker.currentStepTotal();

    for (final objective in pending) {
      objective.startValue = switch (objective.type) {
        // Null when the pedometer is unavailable — the tracker captures
        // it defensively on the first live reading.
        DungeonObjectiveType.steps => steps,
        DungeonObjectiveType.water => water,
        DungeonObjectiveType.walkingDistance ||
        DungeonObjectiveType.runningDistance => distance,
        DungeonObjectiveType.calories => calories,
      };
    }

    await DungeonDailyStore.markSessionStarted(session.gateLetter);
    await DungeonDailyStore.saveProgress(
      session.gateLetter,
      session.allObjectives.toList(),
    );
  }

  // ── Live tracking (session-owned, widget-independent) ────────────────

  /// Tracker follows the SESSION: running while it is active, stopped
  /// once cleared, restarted after any restore of an active session.
  void _syncTracking() {
    final session = _session;
    if (session == null || session.isCleared) {
      _tracker?.dispose();
      _tracker = null;
      return;
    }
    if (_tracker != null) return;
    _tracker = DungeonTracker(onValue: _onSourceValue)..start();
  }

  /// One live reading from a source: progress = current − startValue,
  /// applied monotonically to every matching incomplete objective
  /// (monster or boss), then persisted immediately.
  void _onSourceValue(DungeonObjectiveType type, double current) {
    final session = _session;
    if (session == null || session.isCleared) return;
    // Day rolled over while the app stayed open — the session is stale;
    // the next entry creates a fresh one.
    if (session.day != DungeonDailyStore.today) return;

    var changed = false;
    for (final objective in session.allObjectives) {
      if (objective.type != type || objective.isComplete) continue;
      if (objective.applyCurrentValue(current)) changed = true;
    }
    if (!changed) return;

    DungeonDailyStore.saveProgress(
      session.gateLetter,
      session.allObjectives.toList(),
    );

    // Completion = boss objective reached its target (boss unlocked and
    // 100%). One clear per day — the store enforces the date gate.
    if (session.bossUnlocked && session.boss.isComplete) {
      session.status = DungeonSessionStatus.cleared;
      DungeonDailyStore.markCleared(session.gateLetter);
      _syncTracking(); // Session ended — the tracker stops.
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tracker?.dispose();
    _tracker = null;
    _session = null;
    super.dispose();
  }
}

import 'package:flutter/material.dart';

/// The objective types a dungeon may generate — EXACTLY the metrics Hunter
/// Ascend already tracks automatically:
///
/// * [steps]           — device pedometer (`Pedometer.stepCountStream`),
/// * [water]           — the hunter's shared daily water intake,
/// * [walkingDistance] — GPS distance from saved runs (`runs` collection),
/// * [runningDistance] — GPS distance from saved runs (`runs` collection)
///                       (the run tracker records distance without a
///                       walk/run label — both observe the same source),
/// * [calories]        — calories burned by saved runs (`runs` collection).
///
/// Types with no automatic tracking (push-ups, squats, plank, yoga, ...)
/// are deliberately NOT generated — every dungeon objective must be
/// completable by observation alone, with no manual logging.
enum DungeonObjectiveType {
  steps(label: 'Steps', icon: Icons.directions_walk, unit: 'steps'),
  water(label: 'Water', icon: Icons.water_drop_rounded, unit: 'ml'),
  walkingDistance(
    label: 'Walking',
    icon: Icons.directions_walk_rounded,
    unit: 'km',
  ),
  runningDistance(
    label: 'Running',
    icon: Icons.directions_run_rounded,
    unit: 'km',
  ),
  calories(
    label: 'Calories',
    icon: Icons.local_fire_department_rounded,
    unit: 'kcal',
  );

  const DungeonObjectiveType({
    required this.label,
    required this.icon,
    required this.unit,
  });

  final String label;
  final IconData icon;

  /// Canonical tracking/display unit for the type — the AI is instructed
  /// to emit targets in these units and tracking compares raw values, so
  /// no wording or unit parsing is ever needed at runtime.
  final String unit;

  /// Structured parser for the AI's `type` field — exact type values only
  /// ("steps", "water", "walking_distance", "running_distance",
  /// "calories"). Unknown/unsupported types are rejected, never guessed.
  static DungeonObjectiveType? tryParse(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'steps':
        return steps;
      case 'water':
        return water;
      case 'walking_distance':
      case 'walkingdistance':
        return walkingDistance;
      case 'running_distance':
      case 'runningdistance':
        return runningDistance;
      case 'calories':
      case 'calorie':
        return calories;
    }
    return null;
  }
}

/// Quest lifecycle of a monster objective (timer-based quest system).
/// Explicit states — the UI never infers state from text alone:
///
/// * [notStarted] — START QUEST not pressed yet,
/// * [active] — quest running (timer counting down, objective may be
///   partial or already reached),
/// * [objectiveReachedWaitingForTimer] — the fitness target is hit but
///   the timer still runs: the quest MUST NOT complete early,
/// * [completed] — BOTH requirements satisfied (objective reached AND
///   timer finished).
enum DungeonQuestState {
  notStarted,
  active,
  objectiveReachedWaitingForTimer,
  completed,
}

/// One fitness objective inside a dungeon run — fully STRUCTURED data:
/// [type] tells the tracker which fitness source to observe, [target] is
/// the amount to gain in the type's canonical [unit], and [title] is
/// display-only flavor. Generated ONCE per day via `DungeonGeneration`
/// and persisted — together with its snapshot and live [progress] — by
/// `DungeonDailyStore`.
///
/// Progress uses SNAPSHOT semantics, not session baselines: [startValue]
/// captures the hunter's value ONCE when the dungeon session starts and
/// stays FIXED until the dungeon ends. Progress is always
/// `currentHunterValue - startValue`, so activity performed anywhere in
/// the app (dashboard water, saved runs, steps) counts automatically and
/// nothing ever resets because a screen was rebuilt or reopened. Monster
/// HP drains as [progress] climbs; the monster is defeated when
/// [isComplete].
class DungeonObjective {
  DungeonObjective({
    required this.title,
    required this.type,
    required this.target,
    this.isBoss = false,
    String? monster,
    this.progress = 0,
    this.startValue,
    this.durationSeconds = 0,
    this.questStartedAt,
  }) : monster =
           (monster == null || monster.trim().isEmpty) ? null : monster.trim();

  /// Display-only flavor text ("Drink 2L Water"). NEVER parsed for
  /// tracking — the tracker keys entirely off [type].
  final String title;

  final DungeonObjectiveType type;

  /// Amount to reach, in [unit].
  final double target;

  /// True for the dungeon's boss objective (one per run, unlocks after
  /// every monster is defeated). Parsed by the SAME code path as monster
  /// objectives — no separate boss parsing exists.
  final bool isBoss;

  /// AI-supplied monster name ("Goblin Scout"). Null when absent — the
  /// `DungeonMonsters` fallback bestiary supplies the face and name then.
  final String? monster;

  /// Current progress in [unit] — stored by `DungeonDailyStore` alongside
  /// today's objectives, so it lives OUTSIDE the widget lifecycle
  /// (re-entry restores it instead of resetting it).
  double progress;

  /// SNAPSHOT of the hunter's value for this objective's source taken
  /// ONCE when the dungeon session started (`DungeonSessionManager`),
  /// persisted by the daily store and FIXED until the dungeon ends.
  /// Progress = current hunter value − [startValue]. Null only for
  /// legacy rows / a source that was unreadable at session start — the
  /// manager captures it defensively on the first live reading.
  double? startValue;

  // ── Timer-based quest fields (monsters only — the boss keeps its
  //    pure-progress completion, unchanged) ─────────────────────────────

  /// AI-provided quest duration (structured `durationSeconds`, validated
  /// and clamped at parse time). 0 for the boss and for legacy rows.
  final int durationSeconds;

  /// When START QUEST was pressed — persisted immediately, so the timer
  /// survives navigation, rebuilds and app restarts. The remaining time
  /// is ALWAYS derived from this timestamp ([remainingQuestTime]), never
  /// from an in-memory counter.
  DateTime? questStartedAt;

  /// questEndTime = questStartedAt + durationSeconds.
  DateTime? get questEndTime =>
      questStartedAt?.add(Duration(seconds: durationSeconds));

  /// Whether the quest's timer requirement is satisfied. True only after
  /// the quest was started AND the clock has passed [questEndTime]
  /// (exactly the MissionEngine end-timestamp idiom — no negative
  /// remainders, no restarts).
  bool get timerFinished {
    final end = questEndTime;
    return end != null && !DateTime.now().isBefore(end);
  }

  /// False for the boss and for rows persisted before the quest system —
  /// those keep their original progress-only completion instead of
  /// demanding a timer they never had.
  bool get hasQuestTimer => durationSeconds > 0;

  /// Remaining quest time — always recomputed from the persisted
  /// timestamp, clamped at zero.
  Duration remainingQuestTime() {
    final end = questEndTime;
    if (end == null) return Duration(seconds: durationSeconds);
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// The quest is cleared (monster defeated) ONLY when BOTH requirements
  /// hold: the fitness objective reached AND the timer finished. Neither
  /// alone is enough. Rows without a timer (boss, legacy) clear on
  /// progress alone — their original behavior.
  bool get questCleared => isComplete && (!hasQuestTimer || timerFinished);

  /// Explicit quest state — the UI renders from this, never from text.
  DungeonQuestState get questState {
    if (questCleared) return DungeonQuestState.completed;
    if (questStartedAt == null) return DungeonQuestState.notStarted;
    if (isComplete) return DungeonQuestState.objectiveReachedWaitingForTimer;
    return DungeonQuestState.active;
  }

  /// "10 min" / "1 h 05 min" style label for the AI-provided duration.
  String get durationLabel {
    final minutes = (durationSeconds / 60).ceil();
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return hours > 0
        ? '$hours h ${rest.toString().padLeft(2, '0')} min'
        : '$rest min';
  }

  /// "07:42" countdown label — always derived from [questStartedAt],
  /// clamped at zero (never negative).
  String get remainingQuestLabel {
    final remaining = remainingQuestTime();
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String get unit => type.unit;

  bool get isComplete => progress >= target;

  /// 0..1 completion fraction — 1 minus this is the monster's HP.
  double get fraction => target <= 0 ? 1 : (progress / target).clamp(0.0, 1.0);

  /// "8000 steps" / "2 km" style target label.
  String get targetLabel => '${_fmt(target)} ${type.unit}';

  /// "5200 / 8000 steps" style live progress label.
  String get progressLabel =>
      '${_fmt(progress)} / ${_fmt(target)} ${type.unit}';

  /// Whole numbers for counts, one decimal for km.
  String _fmt(double value) =>
      type.unit == 'km' ? value.toStringAsFixed(1) : value.toStringAsFixed(0);

  /// Snapshot-architecture progress update: progress = [current] −
  /// [startValue], clamped to the target. MONOTONIC — progress only ever
  /// grows, so a source hiccup or device-counter reset can never move a
  /// monster backwards. Returns true when progress actually advanced.
  bool applyCurrentValue(double current) {
    startValue ??= current; // Defensive only — normally fixed at session start.
    final derived = (current - startValue!).clamp(0.0, target);
    if (derived > progress) {
      progress = derived;
      return true;
    }
    return false;
  }
}

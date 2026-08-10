import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_rewards.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_tracker.dart';
import 'package:hunter_ascend/services/xp_service.dart';

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
    this.rewardClaimed = false,
    this.clearReward,
  });

  final String gateLetter;

  /// The rank-based CONTENT template this run plays (Phase 6). Derived
  /// from [gateLetter] — never persisted, since the gate letter maps to
  /// exactly one template and stored objectives already hold the run.
  DungeonTemplate get template =>
      DungeonTemplates.forGate(gateLetter) ?? DungeonTemplates.eRank;

  /// Calendar day the session belongs to — the daily-reset guard.
  final String day;

  final List<DungeonObjective> monsters;
  final DungeonObjective boss;
  final String story;

  /// When the session started (snapshot capture).
  final DateTime startedAt;

  DungeonSessionStatus status;

  /// Whether today's clear reward was already claimed — restored from the
  /// daily store so re-entry/restart can never pay it twice.
  bool rewardClaimed;

  /// Today's claimed reward record (Phase 7) — restored from the daily
  /// store so the cleared screen re-shows the SAME XP/coins without
  /// granting anything again.
  DungeonClearReward? clearReward;

  bool get isCleared => status == DungeonSessionStatus.cleared;

  /// The boss room opens once every monster QUEST is cleared — i.e. each
  /// monster's fitness objective reached AND its timer finished (rows
  /// without a timer count progress alone, as before).
  bool get bossUnlocked =>
      monsters.isNotEmpty && monsters.every((m) => m.questCleared);

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

  /// 1-second UI ticker — alive ONLY while at least one quest timer is
  /// running. Like [MissionEngine]'s countdown it never holds state of
  /// its own: every tick just recomputes the remaining time from the
  /// persisted `questStartedAt` timestamps and repaints listeners.
  Timer? _questTicker;

  /// Serializes enter/restore so double taps and route rebuilds cannot
  /// race into two sessions.
  Future<void>? _opening;

  /// Guards the reward claim against concurrent taps.
  bool _claiming = false;

  // ── View API (the play screen reads ONLY these) ──────────────────────

  DungeonSession? get session => _session;
  bool get hasSession => _session != null;
  List<DungeonObjective> get monsters => _session?.monsters ?? const [];
  DungeonObjective? get boss => _session?.boss;
  String get story => _session?.story ?? '';
  bool get bossUnlocked => _session?.bossUnlocked ?? false;
  bool get isCleared => _session?.isCleared ?? false;
  bool get rewardClaimed => _session?.rewardClaimed ?? false;

  /// Today's claimed reward record (null when unclaimed) — lets the UI
  /// re-show the SAME rewards without granting them again.
  DungeonClearReward? get clearReward => _session?.clearReward;

  /// The active session's content template (null with no session).
  DungeonTemplate? get template => _session?.template;

  /// SEQUENTIAL progression — the ONLY quest that may show START QUEST:
  /// the FIRST uncleared monster, and only while no other quest is
  /// running (at most ONE active quest at any time). Null while a quest
  /// is active (everything else stays locked) or once every monster
  /// quest is cleared (the boss flow takes over).
  DungeonObjective? get nextStartableQuest {
    final session = _session;
    if (session == null || session.isCleared) return null;
    final questRunning = session.monsters.any(
      (m) => m.questStartedAt != null && !m.questCleared,
    );
    if (questRunning) return null;
    for (final monster in session.monsters) {
      if (!monster.questCleared) return monster;
    }
    return null;
  }

  // ── Entry (ENTER DUNGEON press on the gate screen) ───────────────────

  /// Creates/restores today's session for [gate] — SAME engine for every
  /// rank (Phase 6): only the [DungeonTemplates] content differs. AI
  /// generation runs exactly once per day HERE — afterwards the daily
  /// store serves the same dungeon until completion or the daily reset.
  /// Immediately after the dungeon exists, snapshots are captured ONCE
  /// and tracking starts.
  Future<void> enterDungeon({required DungeonGateSpec gate}) async {
    final letter = gate.letter;
    final existing =
        (await DungeonDailyStore.load(letter)).objectivesForToday();
    if (existing == null) {
      final generated = await DungeonGeneration.generateDungeon(
        template: DungeonTemplates.forGate(letter) ?? DungeonTemplates.eRank,
      );
      await DungeonDailyStore.saveObjectives(letter, generated);
    }
    await openSession(letter: letter);
  }

  /// Restores today's session from the daily store (app restart, direct
  /// navigation) — idempotent: a live session for the same gate and day
  /// is reused as-is, never rebuilt.
  Future<void> openSession({required String letter}) {
    return _opening ??= _openSession(
      letter,
    ).whenComplete(() => _opening = null);
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
    final template = DungeonTemplates.forGate(letter) ?? DungeonTemplates.eRank;
    var monsters = state.objectivesForToday();
    var boss = state.bossForToday();
    var story = state.storyForToday();

    if (monsters == null) {
      // Defensive only (e.g. cleared app data) — the local fallback costs
      // NO AI request and is saved so today reuses it like any dungeon.
      final fallback = DungeonGeneration.fallbackDungeon(template);
      await DungeonDailyStore.saveObjectives(letter, fallback);
      monsters = fallback.monsters;
      boss ??= fallback.boss;
      story = fallback.story;
    }

    // Dungeons persisted before the boss system existed get the fallback
    // boss — the run stays clearable without regenerating.
    boss ??= DungeonGeneration.fallbackBoss(template);

    final session = DungeonSession(
      gateLetter: letter,
      day: DungeonDailyStore.today,
      monsters: monsters,
      boss: boss,
      story: story,
      startedAt: state.sessionStartedAt ?? DateTime.now(),
      status:
          state.completedToday
              ? DungeonSessionStatus.cleared
              : DungeonSessionStatus.active,
      // The claim flag only belongs to TODAY's clear — yesterday's flag
      // stays inert in the entry (its completedDate no longer matches).
      rewardClaimed: state.completedToday && state.rewardClaimed,
      // Same date guard for the claimed reward record (Phase 7).
      clearReward: state.completedToday ? state.clearReward : null,
    );
    _session = session;

    await _captureSnapshots(session);
    _syncTracking();
    _syncQuestTicker();
    notifyListeners();
  }

  // ── Quest timers (START QUEST + countdown) ───────────────────────────

  /// Starts one monster's quest — stamps [DungeonObjective.questStartedAt]
  /// and persists it IMMEDIATELY, so `questEndTime = questStartedAt +
  /// durationSeconds` survives navigation, rebuilds and app restarts
  /// (exactly the MissionEngine end-timestamp idiom). Guarded against
  /// re-entry: a started quest can never restart, and the boss / legacy
  /// rows have no quest to start. SEQUENTIAL rule enforced HERE as well
  /// as in the UI: only [nextStartableQuest] may start — never while
  /// another quest is running (one active quest at a time) and never
  /// out of order. ZERO AI calls — the duration already came with the
  /// dungeon generation.
  Future<void> startQuest(DungeonObjective objective) async {
    final session = _session;
    if (session == null || session.isCleared) return;
    if (objective.isBoss || !objective.hasQuestTimer) return;
    if (objective.questStartedAt != null) return; // Already running.
    // One active quest at a time, in list order — double-safety on top
    // of the UI only offering START QUEST on [nextStartableQuest].
    if (!identical(objective, nextStartableQuest)) return;

    objective.questStartedAt = DateTime.now();
    notifyListeners();
    await DungeonDailyStore.saveProgress(
      session.gateLetter,
      session.allObjectives.toList(),
    );
    _syncQuestTicker();
  }

  /// Keeps the 1-second countdown ticker alive exactly while some quest
  /// timer is running — started quests that are not cleared yet. Each
  /// tick only repaints (remaining time is always derived from the
  /// persisted timestamp); quest/boss completion itself is derived state
  /// the listeners re-evaluate. Cancels itself the moment no running
  /// timer remains — it never auto-restarts on its own.
  void _syncQuestTicker() {
    final session = _session;
    final running =
        session != null &&
        !session.isCleared &&
        session.day == DungeonDailyStore.today &&
        session.monsters.any(
          (m) => m.questStartedAt != null && !m.questCleared,
        );
    if (!running) {
      _questTicker?.cancel();
      _questTicker = null;
      return;
    }
    if (_questTicker != null) return;
    _questTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners(); // Countdown repaint — remaining time is derived.
      _syncQuestTicker(); // Stop once the last running timer clears.
    });
  }

  // ── Clear reward (Phase 5 — awarded exactly once) ────────────────────

  /// Claims today's dungeon-clear reward EXACTLY once (Phase 7 bundle:
  /// XP + coins). The XP goes through the centralized [XpService]
  /// (the same awarding path quests, duels and achievements use —
  /// level-up, daily/weekly XP and leaderboard staleness all come for
  /// free; no XP logic is duplicated here). Coins have no live
  /// economy yet — they are recorded with the claim for display and
  /// future integration. All amounts come from the template +
  /// `DungeonRewardBuilder` configuration layer; membership tier never
  /// changes them.
  ///
  /// Exactly-once guarantee: the claim flag AND the reward record are
  /// persisted FIRST, then the XP is awarded; only a FAILED award rolls
  /// both back (the duel-XP idempotency pattern). Rewards are
  /// deterministic per gate + day, so a retry rebuilds the IDENTICAL
  /// record. Re-entry, rebuilds, app restarts and double taps can
  /// therefore never pay the reward twice.
  ///
  /// Returns the claim result, or null when there is nothing to claim
  /// (not cleared, already claimed, claim in flight) or the award failed.
  Future<DungeonClaimResult?> claimClearReward() async {
    final session = _session;
    if (session == null || !session.isCleared) return null;
    if (session.rewardClaimed || _claiming) return null;
    _claiming = true;
    try {
      final reward = DungeonRewardBuilder.build(
        session.template,
        gateLetter: session.gateLetter,
        day: session.day,
      );

      await DungeonDailyStore.markRewardClaimed(
        session.gateLetter,
        claimed: true,
      );
      await DungeonDailyStore.saveClearReward(session.gateLetter, reward);
      session.rewardClaimed = true;
      session.clearReward = reward;
      notifyListeners();

      // The permanent ALL-TIME dungeon leaderboard score rides in the
      // SAME transaction as the XP award — so it inherits this claim's
      // exactly-once gate (no partial/partial-progress points: ONLY a
      // claimed DUNGEON CLEARED ever moves the score). The amount reuses
      // the existing rank-scaled clear reward (higher gate = more score);
      // membership never changes it and the score NEVER resets.
      final result = await XpService.instance.awardXp(
        amount: reward.xp,
        dungeonScore: reward.xp,
      );
      if (result == null) {
        // Award failed (signed out / Firestore error) — roll the claim
        // back so the reward stays claimable instead of being lost.
        await DungeonDailyStore.markRewardClaimed(
          session.gateLetter,
          claimed: false,
        );
        await DungeonDailyStore.clearClearReward(session.gateLetter);
        session.rewardClaimed = false;
        session.clearReward = null;
        notifyListeners();
        return null;
      }
      return DungeonClaimResult(reward: reward, xpAward: result);
    } finally {
      _claiming = false;
    }
  }

  // ── Snapshots (captured ONCE, fixed until the dungeon ends) ──────────

  /// Captures the current hunter values for every objective that still
  /// lacks a snapshot. Rows restored from a previous capture keep their
  /// fixed values — this method NEVER re-anchors an existing snapshot.
  Future<void> _captureSnapshots(DungeonSession session) async {
    final pending =
        session.allObjectives.where((o) => o.startValue == null).toList();
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
      _syncQuestTicker(); // ...and so does the countdown ticker.
    } else {
      // Progress may have cleared a quest whose timer already finished —
      // re-check whether the countdown ticker is still needed.
      _syncQuestTicker();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _questTicker?.cancel();
    _questTicker = null;
    _tracker?.dispose();
    _tracker = null;
    _session = null;
    super.dispose();
  }
}

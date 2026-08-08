import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Daily dungeon persistence (Phase 5) — one entry per gate letter:
///
/// * `lastPlayedDate` — last calendar day the hunter entered the gate.
/// * `completedDate`  — calendar day the dungeon was cleared ("Rewards
///                       Claimed"; one clear per day).
/// * `objectivesDate` — calendar day the stored objectives were generated.
/// * `objectives`     — the day's generated monsters PLUS the boss
///                       objective (`boss: true` flag), so re-entering on
///                       the same day reuses the SAME dungeon instead of
///                       regenerating. Each row also stores its live
///                       `progress`, so monster HP survives leaving the
///                       screen, navigating home or reopening the app.
///                       Objectives only count while `objectivesDate`
///                       equals today — leaving the dungeon, navigating
///                       back or reopening the app never regenerates;
///                       only completion or the daily reset does.
/// * `story`          — the AI story line generated with the dungeon.
///
/// Follows the app's established daily-feature pattern (see
/// `DailyRewardService`): SharedPreferences + the app-wide
/// `DateTime.now().toString().substring(0, 10)` date string. There is no
/// reset timer and no Firestore traffic — the next-day reset falls out of
/// the date comparison automatically: on a new day `completedToday` is
/// false and the stored objectives no longer match, so a fresh dungeon is
/// generated.
///
/// All writes are SERIALIZED through [_writes] — each update is an atomic
/// read-modify-write, so concurrent callers (double entry, route rebuilds)
/// can never clobber the stored dungeon.
class DungeonDailyStore {
  DungeonDailyStore._();

  /// Single prefs key holding a JSON map `{gateLetter: entry}` — one local
  /// read covers every gate.
  static const String _key = 'dungeon_daily_state_v1';

  /// Write serialization chain — every [_update] appends itself here so
  /// read-modify-write cycles never interleave.
  static Future<void> _writes = Future.value();

  /// The app-wide today-string convention (DailyRewardService, dashboard
  /// step offset, water tracking, ...).
  static String get today => DateTime.now().toString().substring(0, 10);

  // ── Reads ──────────────────────────────────────────────────────────────

  static Future<DungeonDailyState> load(String gateLetter) async {
    final all = await _readAll();
    return _stateFrom(all[gateLetter]);
  }

  /// Every gate's daily state in ONE local read (used by the lobby).
  static Future<Map<String, DungeonDailyState>> loadAll() async {
    final all = await _readAll();
    return {
      for (final entry in all.entries) entry.key: _stateFrom(entry.value),
    };
  }

  static DungeonDailyState _stateFrom(dynamic entry) {
    if (entry is! Map) return const DungeonDailyState();
    return DungeonDailyState(
      lastPlayedDate: entry['lastPlayedDate'] as String?,
      completedDate: entry['completedDate'] as String?,
      objectivesDate: entry['objectivesDate'] as String?,
      objectivesJson: entry['objectives'],
      story: entry['story'] as String?,
      startedAt: entry['startedAt'] as String?,
    );
  }

  // ── Writes (each merges into the existing entry) ──────────────────────

  /// Records that the hunter entered this gate today.
  static Future<void> markPlayed(String gateLetter) =>
      _update(gateLetter, (entry) => entry['lastPlayedDate'] = today);

  /// Persists today's generated dungeon — monsters + boss objective +
  /// story (generate-once: they are kept until the dungeon is completed
  /// or the day resets). Stamped with today's date so the store itself
  /// enforces the daily contract.
  static Future<void> saveObjectives(
    String gateLetter,
    GeneratedDungeon dungeon,
  ) =>
      _update(
        gateLetter,
        (entry) {
          entry['objectivesDate'] = today;
          entry['story'] = dungeon.story;
          entry['objectives'] = [
            ...dungeon.monsters.map((o) => _objectiveToJson(o)),
            _objectiveToJson(dungeon.boss),
          ];
        },
      );

  static Map<String, dynamic> _objectiveToJson(DungeonObjective o) => {
        'title': o.title,
        'type': o.type.name,
        'target': o.target,
        if (o.isBoss) 'boss': true,
        if (o.monster != null) 'monster': o.monster,
        // Freshly generated objectives start at zero; [saveProgress]
        // updates this field as the run plays out.
        'progress': o.progress,
        // Session snapshot — the hunter's value when the dungeon started
        // (captured ONCE by DungeonSessionManager; fixed until the
        // dungeon ends). Absent until the session captures it.
        if (o.startValue != null) 'start': o.startValue,
      };

  /// Persists live run progress AND session snapshots into today's saved
  /// objectives (matched by title + boss flag, which are unique within a
  /// generated dungeon). Only the `progress` and `start` fields are
  /// merged — the saved dungeon, its date stamp and every other field
  /// stay untouched, and writes reuse the same serialized chain as every
  /// other daily update.
  static Future<void> saveProgress(
    String gateLetter,
    Iterable<DungeonObjective> objectives,
  ) =>
      _update(
        gateLetter,
        (entry) {
          final rows = entry['objectives'];
          if (rows is! List) return; // Nothing saved today — nothing to merge.
          final byKey = {
            for (final o in objectives) _rowKey(o.title, o.isBoss): o,
          };
          for (final row in rows) {
            if (row is! Map) continue;
            final key = _rowKey(
              (row['title'] ?? '').toString(),
              row['boss'] == true,
            );
            final objective = byKey[key];
            if (objective == null) continue;
            row['progress'] = objective.progress;
            // The snapshot is written once (first capture wins) and never
            // re-anchored afterwards.
            if (objective.startValue != null && row['start'] == null) {
              row['start'] = objective.startValue;
            }
          }
        },
      );

  /// Stamps the session start — written once per day (first entry wins).
  static Future<void> markSessionStarted(String gateLetter) => _update(
        gateLetter,
        (entry) => entry['startedAt'] ??= DateTime.now().toIso8601String(),
      );

  /// Row identity for progress merging — titles are unique inside one
  /// dungeon (the parser dedupes), and the flag keeps a monster and the
  /// boss apart even if the AI reused a title.
  static String _rowKey(String title, bool isBoss) =>
      '${title.trim().toLowerCase()}|${isBoss ? 'boss' : 'monster'}';

  /// Marks the dungeon cleared for today — the one-reward-per-day gate.
  static Future<void> markCleared(String gateLetter) =>
      _update(gateLetter, (entry) => entry['completedDate'] = today);

  // ── Internals ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _readAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (e) {
      debugPrint('[DungeonDaily] read error: $e');
      return {};
    }
  }

  /// Serialized read-modify-write: chained onto [_writes] so concurrent
  /// callers never interleave and clobber each other's data.
  static Future<void> _update(
    String gateLetter,
    void Function(Map<String, dynamic> entry) mutate,
  ) {
    _writes = _writes.then((_) => _updateLocked(gateLetter, mutate));
    return _writes;
  }

  static Future<void> _updateLocked(
    String gateLetter,
    void Function(Map<String, dynamic> entry) mutate,
  ) async {
    try {
      final all = await _readAll();
      final existing = all[gateLetter];
      final entry = existing is Map<String, dynamic>
          ? existing
          : <String, dynamic>{};
      mutate(entry);
      all[gateLetter] = entry;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(all));
    } catch (e) {
      debugPrint('[DungeonDaily] write error: $e');
    }
  }
}

/// Immutable snapshot of one gate's daily state.
class DungeonDailyState {
  const DungeonDailyState({
    this.lastPlayedDate,
    this.completedDate,
    this.objectivesDate,
    this.objectivesJson,
    this.story,
    this.startedAt,
  });

  final String? lastPlayedDate;
  final String? completedDate;

  /// Calendar day the stored objectives were generated — the objectives
  /// only belong to "today" while this matches today's date.
  final String? objectivesDate;
  final dynamic objectivesJson;

  /// The AI story line saved with today's dungeon.
  final String? story;

  /// ISO timestamp of when today's dungeon session started (snapshot
  /// capture) — null for entries saved before sessions existed.
  final String? startedAt;

  /// [startedAt] parsed, or null when absent/unparseable.
  DateTime? get sessionStartedAt => startedAt == null
      ? null
      : DateTime.tryParse(startedAt!);

  /// Cleared sometime today → rewards already claimed, gate locked until
  /// the calendar day rolls over (automatic reset — no timer needed).
  bool get completedToday =>
      completedDate != null && completedDate == DungeonDailyStore.today;

  /// True when the stored dungeon belongs to today — the shared date
  /// guard for monsters, boss and story alike.
  bool get _isToday => objectivesDate == DungeonDailyStore.today;

  /// Today's saved monster objectives (boss excluded), parsed back into
  /// playable form — or null when no dungeon was generated TODAY (never
  /// generated, or the daily reset already passed). Reuses the lenient
  /// type parser from the model so malformed saved rows are skipped,
  /// never fatal.
  List<DungeonObjective>? objectivesForToday() {
    // Date guard: objectives from any previous day are treated as absent,
    // which is what triggers a fresh generation after the daily reset.
    if (!_isToday) return null;
    final objectives = _parseStored();
    if (objectives.isEmpty) return null;
    final monsters = objectives.where((o) => !o.isBoss).toList();
    return monsters.isEmpty ? null : monsters;
  }

  /// Today's saved boss objective — or null when absent (never generated,
  /// day rolled over, or a dungeon persisted before the boss system
  /// existed; the play screen substitutes the fallback boss in that case).
  DungeonObjective? bossForToday() {
    if (!_isToday) return null;
    for (final objective in _parseStored()) {
      if (objective.isBoss) return objective;
    }
    return null;
  }

  /// Today's saved story line ('' when absent).
  String storyForToday() => _isToday ? (story ?? '') : '';

  /// Lenient parse of the stored objectives list (monsters + boss).
  List<DungeonObjective> _parseStored() {
    final json = objectivesJson;
    if (json is! List || json.isEmpty) return [];
    final objectives = <DungeonObjective>[];
    for (final item in json) {
      if (item is! Map) continue;
      final title = (item['title'] ?? '').toString().trim();
      DungeonObjectiveType? type =
          DungeonObjectiveType.tryParse((item['type'] ?? '').toString());
      // Migration for dungeons persisted before the structured schema:
      // the old walk/run types were pedometer step-count objectives, so
      // they map onto `steps` and keep their saved progress. The old
      // manual types (pushups/squats/plank) have no automatic tracker and
      // are dropped.
      type ??= switch ((item['type'] ?? '').toString()) {
        'walk' || 'run' => DungeonObjectiveType.steps,
        _ => null,
      };
      final target = double.tryParse('${item['target']}');
      if (title.isEmpty || type == null || target == null || target <= 0) {
        continue;
      }
      // Restore live progress (rows saved before progress persistence
      // simply start at zero) and the session snapshot (null for rows
      // saved before snapshot tracking — the session manager captures it
      // on the next entry).
      final progress = double.tryParse('${item['progress'] ?? 0}') ?? 0;
      final start = item['start'] == null
          ? null
          : double.tryParse('${item['start']}');
      final monster = (item['monster'] ?? '').toString().trim();
      objectives.add(DungeonObjective(
        title: title,
        type: type,
        target: target,
        isBoss: item['boss'] == true,
        monster: monster.isEmpty ? null : monster,
        progress: progress.clamp(0.0, target),
        startValue: start,
      ));
    }
    return objectives;
  }
}

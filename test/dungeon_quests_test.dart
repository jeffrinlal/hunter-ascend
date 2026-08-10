import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Timer-based quest system — duration validation, quest states, the
/// BOTH-conditions completion rule, and quest-timer persistence.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DungeonObjective quest({
    double progress = 0,
    int duration = 600,
    DateTime? startedAt,
  }) => DungeonObjective(
    title: 'Drink 2L Water',
    type: DungeonObjectiveType.water,
    target: 2000,
    monster: 'Goblin Scout',
    progress: progress,
    durationSeconds: duration,
    questStartedAt: startedAt,
  );

  // ── AI duration validation ────────────────────────────────────────────

  group('sanitizeDuration', () {
    test('accepts values inside the bounds', () {
      expect(DungeonGeneration.sanitizeDuration(60), 60);
      expect(DungeonGeneration.sanitizeDuration(300), 300);
      expect(DungeonGeneration.sanitizeDuration(3600), 3600);
    });

    test('falls back on invalid values — never another AI call', () {
      expect(DungeonGeneration.sanitizeDuration(null), 900);
      expect(DungeonGeneration.sanitizeDuration(0), 900);
      expect(DungeonGeneration.sanitizeDuration(59), 900);
      expect(DungeonGeneration.sanitizeDuration(3601), 900);
      expect(DungeonGeneration.sanitizeDuration(-100), 900);
      expect(DungeonGeneration.sanitizeDuration('garbage'), 900);
    });

    test('coerces numeric-ish values', () {
      expect(DungeonGeneration.sanitizeDuration(300.4), 300);
      expect(DungeonGeneration.sanitizeDuration('600'), 600);
    });
  });

  // ── Explicit quest states ─────────────────────────────────────────────

  group('quest states', () {
    test('not started before START QUEST', () {
      final objective = quest();
      expect(objective.questState, DungeonQuestState.notStarted);
      expect(objective.questCleared, isFalse);
      expect(objective.hasQuestTimer, isTrue);
    });

    test('active while timer runs and objective is partial', () {
      final objective = quest(
        progress: 1500,
        startedAt: DateTime.now().subtract(const Duration(seconds: 60)),
      );
      expect(objective.questState, DungeonQuestState.active);
      expect(objective.timerFinished, isFalse);
      expect(objective.questCleared, isFalse);
    });

    test('reaching the objective EARLY does not complete the quest', () {
      final objective = quest(
        progress: 2000,
        startedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(objective.isComplete, isTrue);
      expect(objective.timerFinished, isFalse);
      expect(
        objective.questState,
        DungeonQuestState.objectiveReachedWaitingForTimer,
      );
      expect(objective.questCleared, isFalse);
    });

    test('timer finished with objective INCOMPLETE does not complete', () {
      final objective = quest(
        progress: 1500,
        startedAt: DateTime.now().subtract(const Duration(seconds: 700)),
      );
      expect(objective.timerFinished, isTrue);
      expect(objective.questState, DungeonQuestState.active);
      expect(objective.questCleared, isFalse);
    });

    test('quest clears only when BOTH conditions hold', () {
      final objective = quest(
        progress: 2000,
        startedAt: DateTime.now().subtract(const Duration(seconds: 700)),
      );
      expect(objective.timerFinished, isTrue);
      expect(objective.isComplete, isTrue);
      expect(objective.questState, DungeonQuestState.completed);
      expect(objective.questCleared, isTrue);
    });

    test('legacy rows without a timer keep progress-only completion', () {
      final objective = quest(duration: 0, progress: 2000);
      expect(objective.hasQuestTimer, isFalse);
      expect(objective.questCleared, isTrue);
      expect(objective.questState, DungeonQuestState.completed);
    });
  });

  // ── Countdown math (end-timestamp idiom, never negative) ─────────────

  group('countdown', () {
    test('remaining time derives from questStartedAt + duration', () {
      final objective = quest(
        startedAt: DateTime.now().subtract(const Duration(seconds: 100)),
      );
      final remaining = objective.remainingQuestTime().inSeconds;
      expect(remaining, inInclusiveRange(499, 501));
    });

    test('remaining time clamps at zero — never negative', () {
      final objective = quest(
        startedAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(objective.remainingQuestTime(), Duration.zero);
      expect(objective.remainingQuestLabel, '00:00');
    });

    test('unstarted quest shows the full duration as remaining', () {
      final objective = quest(duration: 600);
      expect(objective.remainingQuestTime().inSeconds, 600);
      expect(objective.remainingQuestLabel, '10:00');
    });

    test('duration labels', () {
      expect(quest(duration: 600).durationLabel, '10 min');
      expect(quest(duration: 3600).durationLabel, '1 h 00 min');
      expect(quest(duration: 3300).durationLabel, '55 min');
    });
  });

  // ── Persistence (timer survives navigation / restart) ────────────────

  group('quest persistence', () {
    test(
      'duration and START QUEST timestamp round-trip the daily store',
      () async {
        SharedPreferences.setMockInitialValues({});
        final started = DateTime.now().subtract(const Duration(minutes: 2));
        final dungeon = GeneratedDungeon(
          monsters: [
            quest(duration: 600),
            DungeonObjective(
              title: 'Walk 1500 Steps',
              type: DungeonObjectiveType.steps,
              target: 1500,
              monster: 'Goblin Warrior',
              durationSeconds: 900,
            ),
          ],
          boss: DungeonObjective(
            title: 'Walk 2 km',
            type: DungeonObjectiveType.walkingDistance,
            target: 2,
            isBoss: true,
            monster: 'Goblin King',
          ),
          story: 'Goblins ahead.',
        );
        await DungeonDailyStore.saveObjectives('E', dungeon);

        // START QUEST pressed → timestamp merged into the stored row.
        dungeon.monsters[0].questStartedAt = started;
        await DungeonDailyStore.saveProgress('E', dungeon.monsters);

        final state = await DungeonDailyStore.load('E');
        final reloaded = state.objectivesForToday()!;
        expect(reloaded[0].durationSeconds, 600);
        expect(reloaded[1].durationSeconds, 900);
        expect(reloaded[0].questStartedAt, isNotNull);
        expect(
          reloaded[0].questStartedAt!.difference(started).inSeconds.abs(),
          lessThanOrEqualTo(1),
          reason: 'timer must rebuild from the persisted timestamp',
        );
        expect(reloaded[1].questStartedAt, isNull);

        // Boss keeps its no-timer behavior.
        final boss = state.bossForToday()!;
        expect(boss.durationSeconds, 0);
        expect(boss.hasQuestTimer, isFalse);
      },
    );

    test('START QUEST timestamp is write-once — never restarted', () async {
      SharedPreferences.setMockInitialValues({});
      final dungeon = GeneratedDungeon(
        monsters: [quest(duration: 600), quest(duration: 600)],
        boss: DungeonObjective(
          title: 'Walk 2 km',
          type: DungeonObjectiveType.walkingDistance,
          target: 2,
          isBoss: true,
        ),
      );
      // Distinct titles so the rows merge independently.
      dungeon.monsters[1] = DungeonObjective(
        title: 'Walk 1500 Steps',
        type: DungeonObjectiveType.steps,
        target: 1500,
        durationSeconds: 600,
      );
      await DungeonDailyStore.saveObjectives('E', dungeon);

      final first = DateTime.now().subtract(const Duration(minutes: 5));
      dungeon.monsters[0].questStartedAt = first;
      await DungeonDailyStore.saveProgress('E', dungeon.monsters);

      // Simulated second press / restore must NOT re-anchor the timer.
      dungeon.monsters[0].questStartedAt = DateTime.now();
      await DungeonDailyStore.saveProgress('E', dungeon.monsters);

      final reloaded =
          (await DungeonDailyStore.load('E')).objectivesForToday()!;
      expect(
        reloaded[0].questStartedAt!.difference(first).inSeconds.abs(),
        lessThanOrEqualTo(1),
        reason: 'the persisted start timestamp must win (write-once)',
      );
    });
  });
}

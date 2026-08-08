import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_daily_store.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GeneratedDungeon sampleDungeon() => GeneratedDungeon(
        monsters: [
          DungeonObjective(
              title: 'Walk 1500 Steps',
              type: DungeonObjectiveType.steps,
              target: 1500,
              monster: 'Skeleton Grunt'),
          DungeonObjective(
              title: 'Drink 500 ml Water',
              type: DungeonObjectiveType.water,
              target: 500,
              monster: 'Goblin Archer'),
          DungeonObjective(
              title: 'Run 1.5 km',
              type: DungeonObjectiveType.runningDistance,
              target: 1.5,
              monster: 'Giant Spider'),
        ],
        boss: DungeonObjective(
            title: 'Walk 2 km',
            type: DungeonObjectiveType.walkingDistance,
            target: 2,
            isBoss: true,
            monster: 'Goblin King'),
        story: 'Goblins have infested the cave.',
      );

  test('saved dungeon round-trips and is reused on re-entry', () async {
    SharedPreferences.setMockInitialValues({});

    // First entry: mark played + generate + save.
    await DungeonDailyStore.markPlayed('E');
    final generated = sampleDungeon();
    await DungeonDailyStore.saveObjectives('E', generated);

    // Re-entry: markPlayed then load — monsters must come back identical
    // and the boss must NOT be mixed in with them.
    await DungeonDailyStore.markPlayed('E');
    final state = await DungeonDailyStore.load('E');
    final reloaded = state.objectivesForToday();
    expect(reloaded, isNotNull, reason: 'saved dungeon must be reloaded');
    expect(reloaded!.length, 3, reason: 'boss must stay out of the monsters');
    expect(reloaded.map((o) => o.title).toList(),
        generated.monsters.map((o) => o.title).toList());
    expect(reloaded.map((o) => o.type).toList(),
        generated.monsters.map((o) => o.type).toList());
    expect(reloaded.map((o) => o.target).toList(),
        generated.monsters.map((o) => o.target).toList());
    expect(reloaded.map((o) => o.monster).toList(),
        generated.monsters.map((o) => o.monster).toList(),
        reason: 'AI-supplied monster names are structured data and '
            'must round-trip');
    expect(reloaded.every((o) => o.startValue == null), isTrue,
        reason: 'freshly generated rows carry no snapshot until the '
            'session captures one');
    expect(reloaded.every((o) => !o.isBoss), isTrue);

    // Boss objective round-trips separately, flagged as the boss.
    final boss = state.bossForToday();
    expect(boss, isNotNull);
    expect(boss!.title, generated.boss.title);
    expect(boss.type, generated.boss.type);
    expect(boss.target, generated.boss.target);
    expect(boss.monster, generated.boss.monster);
    expect(boss.isBoss, isTrue);

    // Story round-trips too.
    expect(state.storyForToday(), generated.story);
  });

  test(
      'snapshot progress persists across re-entries (leaving / reopening / '
      'app restart)', () async {
    SharedPreferences.setMockInitialValues({});

    // Generate-once + save, then simulate the session capturing snapshots
    // and the hunter making progress against them.
    final generated = sampleDungeon();
    await DungeonDailyStore.saveObjectives('E', generated);
    generated.monsters[0].startValue = 10000; // Device counter at entry.
    generated.monsters[0].applyCurrentValue(10700); // +700 steps → 700/1500.
    generated.boss.startValue = 3.0; // Today's run distance at entry (km).
    generated.boss.applyCurrentValue(4.2); // +1.2 km → 1.2/2.
    await DungeonDailyStore.saveProgress(
      'E',
      [...generated.monsters, generated.boss],
    );

    // Re-entry: progress AND the fixed snapshots must come back exactly
    // where they left off, and the stored dungeon itself must be untouched
    // (no regeneration, no re-anchoring).
    final state = await DungeonDailyStore.load('E');
    final monsters = state.objectivesForToday()!;
    expect(monsters[0].progress, 700);
    expect(monsters[0].startValue, 10000,
        reason: 'the snapshot is persisted and fixed across re-entries');
    expect(monsters[1].progress, 0, reason: 'untouched monsters stay at 0');
    expect(monsters[1].startValue, isNull);
    expect(monsters.map((o) => o.title).toList(),
        generated.monsters.map((o) => o.title).toList());
    final boss = state.bossForToday()!;
    expect(boss.progress, closeTo(1.2, 0.0001));
    expect(boss.startValue, closeTo(3.0, 0.0001));

    // A second session derives progress from the SAME fixed snapshot —
    // it never resets and never creates a new baseline.
    monsters[0].applyCurrentValue(11000); // +1000 since entry.
    await DungeonDailyStore.saveProgress('E', monsters);
    final reloaded = (await DungeonDailyStore.load('E')).objectivesForToday()!;
    expect(reloaded[0].progress, 1000);
    expect(reloaded[0].startValue, 10000);
  });

  test('snapshot progress is monotonic — it never resets or moves backwards',
      () async {
    final objective = DungeonObjective(
        title: 'Walk 1500 Steps',
        type: DungeonObjectiveType.steps,
        target: 1500);
    objective.startValue = 10000;

    expect(objective.applyCurrentValue(10700), isTrue);
    expect(objective.progress, 700);

    // A lower reading (sensor hiccup / device counter reset) must not
    // move the monster backwards.
    expect(objective.applyCurrentValue(500), isFalse);
    expect(objective.progress, 700);

    // Progress clamps at the target.
    expect(objective.applyCurrentValue(99999), isTrue);
    expect(objective.progress, 1500);
    expect(objective.isComplete, isTrue);

    // An objective that lost its snapshot (legacy row) re-captures
    // defensively on the first reading instead of counting history.
    final legacy = DungeonObjective(
        title: 'Drink 500 ml Water',
        type: DungeonObjectiveType.water,
        target: 500,
        progress: 100);
    expect(legacy.startValue, isNull);
    expect(legacy.applyCurrentValue(800), isFalse,
        reason: 'first reading becomes the snapshot — no progress yet');
    expect(legacy.startValue, 800);
    expect(legacy.applyCurrentValue(950), isTrue);
    expect(legacy.progress, 150);
  });

  test('saveProgress merges into the stored entry without clobbering it',
      () async {
    SharedPreferences.setMockInitialValues({});

    await DungeonDailyStore.markPlayed('E');
    await DungeonDailyStore.saveObjectives('E', sampleDungeon());
    await DungeonDailyStore.markCleared('E');
    await DungeonDailyStore.markSessionStarted('E');
    final startedAt = (await DungeonDailyStore.load('E')).sessionStartedAt;
    expect(startedAt, isNotNull,
        reason: 'the session start stamp must persist');

    final monsters = (await DungeonDailyStore.load('E')).objectivesForToday()!;
    monsters[1].startValue = 300;
    monsters[1].applyCurrentValue(550); // Water monster: 250 / 500.
    await DungeonDailyStore.saveProgress('E', monsters);

    final state = await DungeonDailyStore.load('E');
    expect(state.objectivesForToday()![1].progress, 250);
    expect(state.objectivesForToday()![1].startValue, 300);
    expect(state.completedToday, isTrue,
        reason: 'progress writes must not touch the clear state');
    expect(state.sessionStartedAt, startedAt,
        reason: 'progress writes must not touch the session stamp');
    expect(state.objectivesForToday()!.length, 3,
        reason: 'progress writes must not touch the dungeon itself');
    expect(state.bossForToday()!.progress, 0,
        reason: 'unsent rows keep their stored value');

    // The snapshot is written once — a later save can never re-anchor it.
    final again = state.objectivesForToday()!;
    again[1].startValue = 999; // Simulate a bad re-anchor attempt.
    await DungeonDailyStore.saveProgress('E', again);
    expect((await DungeonDailyStore.load('E')).objectivesForToday()![1].startValue,
        300, reason: 'first capture wins — snapshots are never re-anchored');
  });

  test('objectives from a previous day are ignored (daily reset)', () async {
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toString()
        .substring(0, 10);
    SharedPreferences.setMockInitialValues({
      'dungeon_daily_state_v1': jsonEncode({
        'E': {
          'lastPlayedDate': yesterday,
          'objectivesDate': yesterday,
          'objectives': [
            {'title': 'Old Walk', 'type': 'steps', 'target': 1000},
            {'title': 'Old Water', 'type': 'water', 'target': 500},
            {
              'title': 'Old Boss',
              'type': 'walking_distance',
              'target': 2,
              'boss': true
            },
          ],
          'story': 'Old story',
        },
      }),
    });

    final state = await DungeonDailyStore.load('E');
    expect(state.objectivesForToday(), isNull,
        reason: 'yesterday\'s dungeon must not be reused after the reset');
    expect(state.bossForToday(), isNull);
    expect(state.storyForToday(), '');
    expect(state.completedToday, isFalse);
  });

  test('legacy entries migrate: walk/run → steps, manual types dropped',
      () async {
    // Dungeons persisted before the structured schema used the old type
    // names. The store maps walk/run onto `steps` (same pedometer source,
    // same unit) so saved progress survives; manual types without
    // automatic tracking are dropped. Rows without a `monster` field load
    // with a null monster (the fallback bestiary supplies the identity),
    // and rows without a `start` field load with a null snapshot — the
    // session manager captures it on the next entry.
    SharedPreferences.setMockInitialValues({
      'dungeon_daily_state_v1': jsonEncode({
        'E': {
          'objectivesDate': DungeonDailyStore.today,
          'objectives': [
            {'title': 'Walk', 'type': 'walk', 'target': 1000, 'progress': 400},
            {'title': 'Run', 'type': 'run', 'target': 800},
            {'title': 'Push-ups', 'type': 'pushups', 'target': 10},
            {'title': 'Water', 'type': 'water', 'target': 500},
          ],
        },
      }),
    });

    final state = await DungeonDailyStore.load('E');
    final monsters = state.objectivesForToday();
    expect(monsters?.length, 3,
        reason: 'walk + run + water survive; pushups is dropped');
    expect(monsters!.map((o) => o.type).toList(), [
      DungeonObjectiveType.steps,
      DungeonObjectiveType.steps,
      DungeonObjectiveType.water,
    ]);
    expect(monsters[0].progress, 400,
        reason: 'migrated rows keep their saved progress');
    expect(monsters.every((o) => o.monster == null), isTrue,
        reason: 'legacy rows carry no monster — the fallback bestiary '
            'supplies the identity');
    expect(monsters.every((o) => o.startValue == null), isTrue,
        reason: 'legacy rows carry no snapshot — the session captures '
            'one on the next entry');
    expect(state.bossForToday(), isNull,
        reason: 'legacy entries have no boss row — the session manager '
            'substitutes the fallback boss');
  });

  test('concurrent writes are serialized and never clobber objectives',
      () async {
    SharedPreferences.setMockInitialValues({});

    final dungeon = GeneratedDungeon(
      monsters: [
        DungeonObjective(
            title: 'Walk 1500 Steps',
            type: DungeonObjectiveType.steps,
            target: 1500,
            monster: 'Skeleton Grunt'),
        DungeonObjective(
            title: 'Burn 100 kcal',
            type: DungeonObjectiveType.calories,
            target: 100,
            monster: 'Orc Warrior'),
      ],
      boss: DungeonObjective(
          title: 'Walk 2 km',
          type: DungeonObjectiveType.walkingDistance,
          target: 2,
          isBoss: true,
          monster: 'Goblin King'),
    );

    // Fire markPlayed/saveObjectives/markCleared/markSessionStarted
    // concurrently — the serialized write chain must keep every field
    // intact.
    await Future.wait([
      DungeonDailyStore.markPlayed('E'),
      DungeonDailyStore.saveObjectives('E', dungeon),
      DungeonDailyStore.markCleared('E'),
      DungeonDailyStore.markSessionStarted('E'),
    ]);

    final state = await DungeonDailyStore.load('E');
    expect(state.objectivesForToday()?.length, 2,
        reason: 'objectives must survive concurrent writes');
    expect(state.bossForToday()?.isBoss, isTrue,
        reason: 'the boss must survive concurrent writes');
    expect(state.completedToday, isTrue);
    expect(state.sessionStartedAt, isNotNull);
  });
}

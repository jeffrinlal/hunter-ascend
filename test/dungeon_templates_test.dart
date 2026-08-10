import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_gates.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_generation.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_objective.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/services/rank_service.dart';

/// Phase 6 — rank progression & dungeon templates.
///
/// Pure-configuration tests (no Firebase/prefs mocks needed): the six
/// rank templates, the difficulty/reward configuration and the
/// template-driven fallback dungeons.
void main() {
  group('DungeonTemplates registry', () {
    test('covers all six ranks E–S exactly once, ascending', () {
      expect(DungeonTemplates.all.length, 6);
      final letters = DungeonTemplates.all.map((t) => t.rankLetter).toList();
      expect(letters, ['E', 'D', 'C', 'B', 'A', 'S']);
      final ids = DungeonTemplates.all.map((t) => t.id).toSet();
      expect(ids.length, 6, reason: 'template ids must be unique');
    });

    test('spec content: names and bosses match the rank table', () {
      final byRank = {for (final t in DungeonTemplates.all) t.rankLetter: t};
      expect(byRank['E']!.name, 'Goblin Cave');
      expect(byRank['E']!.boss.name, 'Goblin King');
      expect(byRank['D']!.name, 'Spider Nest');
      expect(byRank['D']!.boss.name, 'Spider Queen');
      expect(byRank['C']!.name, 'Skeleton Crypt');
      expect(byRank['C']!.boss.name, 'Skeleton King');
      expect(byRank['B']!.name, 'Orc Fortress');
      expect(byRank['B']!.boss.name, 'Orc Warlord');
      expect(byRank['A']!.name, 'Shadow Temple');
      expect(byRank['A']!.boss.name, 'Shadow Lord');
      expect(byRank['S']!.name, 'Demon Castle');
      expect(byRank['S']!.boss.name, 'Demon Monarch');
    });

    test('monster pools match the master-build content table', () {
      final byRank = {for (final t in DungeonTemplates.all) t.rankLetter: t};
      final expected = {
        'E': ['Goblin Scout', 'Goblin Archer', 'Goblin Warrior'],
        'D': ['Spiderling', 'Venom Spider', 'Giant Spider'],
        'C': ['Skeleton Soldier', 'Skeleton Archer', 'Skeleton Knight'],
        'B': ['Orc Scout', 'Orc Warrior', 'Orc Berserker'],
        'A': ['Shadow Assassin', 'Shadow Knight', 'Shadow Beast'],
        'S': ['Demon Soldier', 'Demon Knight', 'Demon Beast'],
      };
      for (final entry in expected.entries) {
        final pool = byRank[entry.key]!.monsters.map((m) => m.name).toList();
        expect(
          pool.toSet(),
          entry.value.toSet(),
          reason: '${entry.key} rank pool must match the content table',
        );
      }
    });

    test('every template carries full content + one boss + monster pool', () {
      for (final t in DungeonTemplates.all) {
        expect(t.name.isNotEmpty, isTrue);
        expect(t.description.isNotEmpty, isTrue);
        expect(t.theme.isNotEmpty, isTrue);
        expect(t.lore.isNotEmpty, isTrue);
        expect(t.boss.name.isNotEmpty, isTrue);
        expect(
          t.monsters.length,
          greaterThanOrEqualTo(3),
          reason: '${t.id}: pool must cover 3 monster objectives',
        );
        final names = t.monsters.map((m) => m.name.toLowerCase()).toSet();
        expect(
          names.length,
          t.monsters.length,
          reason: '${t.id}: pool names must be unique',
        );
        expect(
          names.contains(t.boss.name.toLowerCase()),
          isFalse,
          reason: '${t.id}: boss must not double as a pool monster',
        );
      }
    });

    test('difficulty labels follow the rank ladder direction', () {
      final labels =
          DungeonTemplates.all.map((t) => t.difficulty.label).toList();
      expect(labels, [
        'Beginner',
        'Easy',
        'Moderate',
        'Hard',
        'Very Hard',
        'Extreme',
      ]);
    });

    test('rewards scale with rank and stay centralized (E keeps 100 XP)', () {
      final rewards = DungeonTemplates.all.map((t) => t.rewardXp).toList();
      for (var i = 1; i < rewards.length; i++) {
        expect(
          rewards[i],
          greaterThan(rewards[i - 1]),
          reason: 'higher rank must pay strictly more XP',
        );
      }
      expect(
        rewards.first,
        100,
        reason: 'E-Rank reward must match the Phase 5 value',
      );
    });

    test(
      'unlock levels reuse the existing Hunter Rank ladder (no dup math)',
      () {
        for (final t in DungeonTemplates.all) {
          final canonical = RankService.ranks.firstWhere(
            (r) => r.letter == t.rankLetter,
          );
          expect(t.recommendedLevel, canonical.minLevel);
          expect(t.rank.tier, canonical.tier);
        }
      },
    );

    test('difficulty config: allowed types are auto-tracked and bounded', () {
      const supported = DungeonObjectiveType.values;
      for (final t in DungeonTemplates.all) {
        final profile = t.difficulty;
        expect(profile.allowedTypes, isNotEmpty);
        for (final type in profile.allowedTypes) {
          expect(
            supported.contains(type),
            isTrue,
            reason: '${t.id}: only auto-tracked types allowed',
          );
          final bounds = profile.targets[type];
          expect(
            bounds,
            isNotNull,
            reason: '${t.id}: missing bounds for $type',
          );
          final (mMin, mMax) = bounds!.range(isBoss: false);
          final (bMin, bMax) = bounds.range(isBoss: true);
          expect(mMin, greaterThan(0));
          expect(mMax, greaterThanOrEqualTo(mMin));
          expect(bMax, greaterThanOrEqualTo(bMin));
          expect(
            bMax,
            greaterThanOrEqualTo(mMax),
            reason: '${t.id}: boss must never be easier than monsters',
          );
        }
      }
    });

    test(
      'running distance only appears from D rank upward (beginner-safe)',
      () {
        final e = DungeonTemplates.forGate('E')!;
        expect(
          e.difficulty.allowedTypes,
          isNot(contains(DungeonObjectiveType.runningDistance)),
        );
        for (final letter in ['D', 'C', 'B', 'A', 'S']) {
          expect(
            DungeonTemplates.forGate(letter)!.difficulty.allowedTypes,
            contains(DungeonObjectiveType.runningDistance),
          );
        }
      },
    );

    test('forGate resolves every rank letter and rejects unknowns', () {
      for (final letter in ['E', 'D', 'C', 'B', 'A', 'S']) {
        expect(DungeonTemplates.forGate(letter), isNotNull);
        expect(DungeonTemplates.forGate(letter)!.rankLetter, letter);
      }
      expect(DungeonTemplates.forGate('X'), isNull);
      expect(DungeonTemplates.eRank.rankLetter, 'E');
    });
  });

  group('Lobby gate specs derive from templates', () {
    test('six gates, same names/difficulties as the templates', () {
      expect(kDungeonGates.length, 6);
      for (var i = 0; i < kDungeonGates.length; i++) {
        final spec = kDungeonGates[i];
        final template = DungeonTemplates.all[i];
        expect(spec.letter, template.rankLetter);
        expect(spec.name, template.name);
        expect(spec.difficulty, template.difficulty.label);
        expect(spec.description, template.description);
        expect(spec.lore, template.lore);
      }
    });
  });

  group('Template-driven fallback dungeons (no AI traffic)', () {
    test('every rank fallback is complete, pool-named and within bounds', () {
      for (final t in DungeonTemplates.all) {
        final dungeon = DungeonGeneration.fallbackDungeon(t);

        expect(dungeon.monsters.length, greaterThanOrEqualTo(2));
        for (final monster in dungeon.monsters) {
          expect(monster.isBoss, isFalse);
          expect(
            t.hasMonster(monster.monster),
            isTrue,
            reason: '${t.id}: fallback monster must come from the pool',
          );
          expect(monster.target, greaterThan(0));
          final (min, max) = t.difficulty.targetRange(
            monster.type,
            isBoss: false,
          );
          expect(monster.target, inInclusiveRange(min, max));
          expect(monster.title.isNotEmpty, isTrue);
        }

        final boss = dungeon.boss;
        expect(boss.isBoss, isTrue);
        expect(
          boss.monster,
          t.boss.name,
          reason: '${t.id}: boss identity is app-controlled',
        );
        final (bMin, bMax) = t.difficulty.targetRange(boss.type, isBoss: true);
        expect(boss.target, inInclusiveRange(bMin, bMax));
      }
    });

    test('E-Rank fallback keeps the beginner experience playable', () {
      final e = DungeonTemplates.eRank;
      final dungeon = DungeonGeneration.fallbackDungeon(e);
      // Beginner types only — never running at E rank.
      for (final o in [...dungeon.monsters, dungeon.boss]) {
        expect(o.type, isNot(DungeonObjectiveType.runningDistance));
      }
      expect(dungeon.boss.monster, 'Goblin King');
    });
  });
}

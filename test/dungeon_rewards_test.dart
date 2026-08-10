import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_rewards.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';

/// Phase 7 — loot, clear reveal & completion experience.
///
/// Pure reward-CONFIGURATION tests (no Firebase/prefs mocks needed):
/// deterministic per-day reward building, rank-scaled coin ranges,
/// loot-table membership and the persisted record round-trip.
void main() {
  group('DungeonRewardBuilder (deterministic, config-driven)', () {
    test('same gate + day always rebuilds the IDENTICAL reward', () {
      final template = DungeonTemplates.eRank;
      final a = DungeonRewardBuilder.build(
        template,
        gateLetter: 'E',
        day: '2026-08-08',
      );
      final b = DungeonRewardBuilder.build(
        template,
        gateLetter: 'E',
        day: '2026-08-08',
      );
      expect(b.xp, a.xp);
      expect(b.coins, a.coins);
      expect(b.lootName, a.lootName);
      expect(b.lootEmoji, a.lootEmoji);
    });

    test('XP always equals the template rank reward', () {
      for (final t in DungeonTemplates.all) {
        final reward = DungeonRewardBuilder.build(
          t,
          gateLetter: t.rankLetter,
          day: '2026-08-08',
        );
        expect(reward.xp, t.rewardXp);
      }
    });

    test('coins stay inside the template-configured range for every rank', () {
      for (final t in DungeonTemplates.all) {
        // Sample many days so the seeded RNG is exercised broadly.
        for (var d = 1; d <= 60; d++) {
          final month = ((d % 12) + 1).toString().padLeft(2, '0');
          final dayOfMonth = ((d % 28) + 1).toString().padLeft(2, '0');
          final day = '2026-$month-$dayOfMonth';
          final reward = DungeonRewardBuilder.build(
            t,
            gateLetter: t.rankLetter,
            day: day,
          );
          expect(
            reward.coins,
            inInclusiveRange(t.coinsMin, t.coinsMax),
            reason: '${t.id}: coins out of configured range',
          );
        }
      }
    });

    test('loot always comes from the template loot table', () {
      for (final t in DungeonTemplates.all) {
        final table = {for (final l in t.lootTable) l.name: l.emoji};
        for (var d = 1; d <= 30; d++) {
          final reward = DungeonRewardBuilder.build(
            t,
            gateLetter: t.rankLetter,
            day: '2026-07-$d',
          );
          expect(
            table.containsKey(reward.lootName),
            isTrue,
            reason: '${t.id}: loot "${reward.lootName}" not in the table',
          );
          expect(reward.lootEmoji, table[reward.lootName]);
        }
      }
    });

    test('coin ranges scale upward with rank (E → S)', () {
      final maxes = DungeonTemplates.all.map((t) => t.coinsMax).toList();
      for (var i = 1; i < maxes.length; i++) {
        expect(
          maxes[i],
          greaterThan(maxes[i - 1]),
          reason: 'higher rank must pay strictly more coins',
        );
      }
    });
  });

  group('Template reward configuration (Phase 7 additions)', () {
    test('every template has a reward tier and a non-empty loot table', () {
      for (final t in DungeonTemplates.all) {
        expect(t.rewardTier.isNotEmpty, isTrue);
        expect(t.lootTable.length, greaterThanOrEqualTo(2));
        expect(t.coinsMax, greaterThanOrEqualTo(t.coinsMin));
        for (final loot in t.lootTable) {
          expect(loot.name.isNotEmpty, isTrue);
          expect(loot.emoji.isNotEmpty, isTrue);
        }
      }
    });

    test('reward tiers follow the rank direction Basic → Highest', () {
      final tiers = DungeonTemplates.all.map((t) => t.rewardTier).toList();
      expect(tiers, [
        'Basic',
        'Improved',
        'Moderate',
        'High',
        'Very High',
        'Highest',
      ]);
    });
  });

  group('DungeonClearReward persistence record', () {
    test('toJson/fromJson round-trip keeps every field', () {
      const reward = DungeonClearReward(
        xp: 100,
        coins: 17,
        lootName: "Hunter's Reward",
        lootEmoji: '🎁',
      );
      final parsed = DungeonClearReward.fromJson(reward.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.xp, reward.xp);
      expect(parsed.coins, reward.coins);
      expect(parsed.lootName, reward.lootName);
      expect(parsed.lootEmoji, reward.lootEmoji);
    });

    test('fromJson is lenient — unusable records parse to null', () {
      expect(DungeonClearReward.fromJson(null), isNull);
      expect(DungeonClearReward.fromJson('garbage'), isNull);
      expect(DungeonClearReward.fromJson(<String, dynamic>{}), isNull);
      expect(
        DungeonClearReward.fromJson({'xp': 'x', 'coins': 1, 'loot': 'a'}),
        isNull,
      );
      expect(
        DungeonClearReward.fromJson({'xp': 1, 'coins': 1}),
        isNull,
        reason: 'missing loot name is unusable',
      );
    });

    test('missing loot emoji defaults to the gift box', () {
      final parsed = DungeonClearReward.fromJson({
        'xp': 100,
        'coins': 12,
        'loot': 'Goblin Token',
      });
      expect(parsed, isNotNull);
      expect(parsed!.lootEmoji, '🎁');
    });
  });
}

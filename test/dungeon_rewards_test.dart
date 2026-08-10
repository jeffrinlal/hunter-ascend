import 'package:flutter_test/flutter_test.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_rewards.dart';
import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';

/// Phase 7 — clear reveal & completion experience.
///
/// Pure reward-CONFIGURATION tests (no Firebase/prefs mocks needed):
/// deterministic per-day reward building and rank-scaled coin ranges.
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
    test('every template has a reward tier and valid coin range', () {
      for (final t in DungeonTemplates.all) {
        expect(t.rewardTier.isNotEmpty, isTrue);
        expect(t.coinsMax, greaterThanOrEqualTo(t.coinsMin));
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
      );
      final parsed = DungeonClearReward.fromJson(reward.toJson());
      expect(parsed, isNotNull);
      expect(parsed!.xp, reward.xp);
      expect(parsed.coins, reward.coins);
    });

    test('fromJson is lenient — unusable records parse to null', () {
      expect(DungeonClearReward.fromJson(null), isNull);
      expect(DungeonClearReward.fromJson('garbage'), isNull);
      expect(DungeonClearReward.fromJson(<String, dynamic>{}), isNull);
      expect(
        DungeonClearReward.fromJson({'xp': 'x', 'coins': 1}),
        isNull,
      );
      expect(
        DungeonClearReward.fromJson({'xp': 1}),
        isNull,
        reason: 'missing coins is unusable',
      );
    });
  });
}

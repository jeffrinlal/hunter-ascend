import 'dart:math';

import 'package:hunter_ascend/screens/dungeon/dungeon_templates.dart';
import 'package:hunter_ascend/services/xp_service.dart';

/// The persisted record of one dungeon-clear reward (Phase 7).
///
/// Written by [DungeonSessionManager.claimClearReward] EXACTLY once per
/// day per gate (claim-first idempotency, same pattern as the XP flag)
/// and restored on re-entry — so reopening a completed dungeon replays
/// the presentation but can never grant anything twice. XP is the only
/// reward backed by a live economy (the centralized [XpService]); the
/// app has NO coin economy yet, so coins are recorded here for display
/// and future integration instead of a wallet.
class DungeonClearReward {
  const DungeonClearReward({
    required this.xp,
    required this.coins,
  });

  final int xp;
  final int coins;

  Map<String, dynamic> toJson() => {
    'xp': xp,
    'coins': coins,
  };

  /// Lenient parse of a stored record — null when unusable.
  static DungeonClearReward? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final xp = int.tryParse('${raw['xp']}');
    final coins = int.tryParse('${raw['coins']}');
    if (xp == null || coins == null) return null;
    return DungeonClearReward(
      xp: xp,
      coins: coins,
    );
  }
}

/// The outcome of a successful claim — the persisted reward plus the live
/// [XpAwardResult] (level-up detection for the shared celebrations).
class DungeonClaimResult {
  const DungeonClaimResult({required this.reward, required this.xpAward});

  final DungeonClearReward reward;
  final XpAwardResult xpAward;
}

/// Reward calculation layer (Phase 7) — ALL reward math lives here and in
/// the [DungeonTemplates] configuration; UI widgets only present results.
///
/// Rewards are DETERMINISTIC per gate + calendar day: the same seed is
/// rebuilt on every call, so a claim retry after a failed XP award always
/// resolves to the IDENTICAL coins, and the persisted record always
/// matches what the hunter saw. No AI is ever involved.
class DungeonRewardBuilder {
  DungeonRewardBuilder._();

  /// Builds today's clear reward for [template] — XP from the template's
  /// rank-scaled `rewardXp` and coins inside its configured range.
  static DungeonClearReward build(
    DungeonTemplate template, {
    required String gateLetter,
    required String day,
  }) {
    final rng = Random(Object.hash(gateLetter, day, 'dungeon-clear-reward'));
    final coins =
        template.coinsMin +
        rng.nextInt(template.coinsMax - template.coinsMin + 1);
    return DungeonClearReward(
      xp: template.rewardXp,
      coins: coins,
    );
  }
}

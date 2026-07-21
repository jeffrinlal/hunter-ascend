import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/rank_reward.dart';
import 'package:hunter_ascend/data/rank_rewards_catalog.dart';

/// Small public badge indicator, shown next to a hunter's name wherever
/// their profile is displayed (own Profile, Dashboard, Global Rankings,
/// Compare Hunters, Public Hunter Profile).
///
/// Purely presentational: resolves [badgeId] against the static
/// [kRankRewardsById] catalog (no Firestore access here) and renders nothing
/// if [badgeId] is `null` or no longer matches a catalog entry — the
/// equipped state itself always comes from the `equippedBadgeId` field
/// already present on whichever hunter document the caller has in hand.
class EquippedBadgeChip extends StatelessWidget {
  final String? badgeId;
  final double size;

  const EquippedBadgeChip({super.key, required this.badgeId, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final id = badgeId;
    if (id == null) return const SizedBox.shrink();
    final reward = kRankRewardsById[id];
    if (reward == null) return const SizedBox.shrink();

    return Tooltip(
      message: reward.name,
      child: Container(
        padding: EdgeInsets.all(size * 0.28),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: reward.color.withOpacity(0.16),
          border: Border.all(color: reward.color.withOpacity(0.55)),
          boxShadow: [
            BoxShadow(color: reward.color.withOpacity(0.35 * HunterTheme.glowStrength), blurRadius: size * 0.5),
          ],
        ),
        child: Icon(reward.type.icon, color: reward.color, size: size),
      ),
    );
  }
}

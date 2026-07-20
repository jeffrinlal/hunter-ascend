import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Categories of permanent cosmetic/functional rewards a Hunter Rank can
/// grant. Generic and data-driven so future reward types can be added here
/// without touching [RankRewardService] or any screen.
enum RankRewardType {
  title,
  badge,
  border,
  aura,
  dashboardTheme,
  reportStyle,
  profileEffect,
}

extension RankRewardTypeX on RankRewardType {
  String get label {
    switch (this) {
      case RankRewardType.title:
        return 'Title';
      case RankRewardType.badge:
        return 'Badge';
      case RankRewardType.border:
        return 'Border';
      case RankRewardType.aura:
        return 'Aura';
      case RankRewardType.dashboardTheme:
        return 'Dashboard Theme';
      case RankRewardType.reportStyle:
        return 'Report Style';
      case RankRewardType.profileEffect:
        return 'Profile Effect';
    }
  }

  IconData get icon {
    switch (this) {
      case RankRewardType.title:
        return Icons.workspace_premium_rounded;
      case RankRewardType.badge:
        return Icons.military_tech_rounded;
      case RankRewardType.border:
        return Icons.crop_square_rounded;
      case RankRewardType.aura:
        return Icons.auto_awesome_rounded;
      case RankRewardType.dashboardTheme:
        return Icons.dashboard_customize_rounded;
      case RankRewardType.reportStyle:
        return Icons.description_rounded;
      case RankRewardType.profileEffect:
        return Icons.blur_on_rounded;
    }
  }
}

/// A single permanent reward tied to a Hunter Rank tier.
///
/// Rewards are resolved and granted purely from [rankTier] — the SAME ordinal
/// produced by `RankService.tierForLevel`/`HunterRank.tier`. This class never
/// computes rank itself; it only reacts to a rank already resolved elsewhere,
/// so rank calculation stays entirely inside `RankService`.
///
/// [id] MUST be globally unique and stable forever — it is used as the
/// Firestore document ID for permanent ownership records, so renaming it
/// would cause a reward to be (harmlessly) re-granted under a new ID rather
/// than recognized as already owned.
@immutable
class RankReward {
  /// Stable, unique identifier (also the Firestore doc ID once granted).
  final String id;

  /// The ordinal rank tier that unlocks this reward (`E = 0` … `Ascend
  /// Legend = 11`, matching `RankService`/`HunterRank.tier`).
  final int rankTier;

  final RankRewardType type;

  /// Display name, e.g. "Rising Hunter" (title) or "Bronze Border".
  final String name;

  /// Short flavor/description text for reward UI (later phases).
  final String description;

  /// Theme-aware accent color for this reward's presentation.
  final Color color;

  const RankReward({
    required this.id,
    required this.rankTier,
    required this.type,
    required this.name,
    required this.description,
    required this.color,
  });
}

/// A reward the hunter has permanently unlocked, with the timestamp it was
/// first granted.
@immutable
class OwnedRankReward {
  final RankReward reward;
  final DateTime unlockedAt;

  const OwnedRankReward({required this.reward, required this.unlockedAt});
}

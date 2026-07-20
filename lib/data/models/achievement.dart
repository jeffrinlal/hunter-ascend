import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';

/// Four RPG-style rarity tiers, each with its own premium appearance.
enum AchievementRarity { common, rare, epic, legendary }

extension AchievementRarityX on AchievementRarity {
  String get label {
    switch (this) {
      case AchievementRarity.common:
        return 'Common';
      case AchievementRarity.rare:
        return 'Rare';
      case AchievementRarity.epic:
        return 'Epic';
      case AchievementRarity.legendary:
        return 'Legendary';
    }
  }

  /// Theme-aware accent for the rarity (⚪ silver, 🟢 green, 🟣 purple, 🟡 gold).
  Color get color {
    switch (this) {
      case AchievementRarity.common:
        return HunterTheme.silver;
      case AchievementRarity.rare:
        return HunterTheme.success;
      case AchievementRarity.epic:
        return HunterTheme.purple;
      case AchievementRarity.legendary:
        return HunterTheme.gold;
    }
  }

  /// Legendary achievements get a stronger glow than the rest.
  double get glow {
    switch (this) {
      case AchievementRarity.legendary:
        return 1.0;
      case AchievementRarity.epic:
        return 0.7;
      case AchievementRarity.rare:
        return 0.45;
      case AchievementRarity.common:
        return 0.25;
    }
  }
}

/// Achievement categories surfaced as filter chips in the Achievements screen.
enum AchievementCategory {
  account,
  progress,
  quests,
  discipline,
  nutrition,
  hydration,
  walking,
  explorer,
  duels,
  social,
  body,
  membership,
  special,
  hidden,
}

extension AchievementCategoryX on AchievementCategory {
  String get label {
    switch (this) {
      case AchievementCategory.account:
        return 'Account';
      case AchievementCategory.progress:
        return 'Progress';
      case AchievementCategory.quests:
        return 'Quests';
      case AchievementCategory.discipline:
        return 'Discipline';
      case AchievementCategory.nutrition:
        return 'Nutrition';
      case AchievementCategory.hydration:
        return 'Hydration';
      case AchievementCategory.walking:
        return 'Walking';
      case AchievementCategory.explorer:
        return 'Explorer';
      case AchievementCategory.duels:
        return 'Duels';
      case AchievementCategory.social:
        return 'Social';
      case AchievementCategory.body:
        return 'Body';
      case AchievementCategory.membership:
        return 'Membership';
      case AchievementCategory.special:
        return 'Special';
      case AchievementCategory.hidden:
        return 'Hidden';
    }
  }

  IconData get icon {
    switch (this) {
      case AchievementCategory.account:
        return Icons.badge_rounded;
      case AchievementCategory.progress:
        return Icons.trending_up_rounded;
      case AchievementCategory.quests:
        return Icons.checklist_rounded;
      case AchievementCategory.discipline:
        return Icons.local_fire_department_rounded;
      case AchievementCategory.nutrition:
        return Icons.restaurant_rounded;
      case AchievementCategory.hydration:
        return Icons.water_drop_rounded;
      case AchievementCategory.walking:
        return Icons.directions_walk_rounded;
      case AchievementCategory.explorer:
        return Icons.explore_rounded;
      case AchievementCategory.duels:
        return Icons.sports_kabaddi_rounded;
      case AchievementCategory.social:
        return Icons.groups_rounded;
      case AchievementCategory.body:
        return Icons.monitor_weight_rounded;
      case AchievementCategory.membership:
        return Icons.workspace_premium_rounded;
      case AchievementCategory.special:
        return Icons.auto_awesome_rounded;
      case AchievementCategory.hidden:
        return Icons.help_rounded;
    }
  }
}

/// A single achievement definition.
///
/// Unlock state and progress are derived purely from the hunter's existing
/// [HunterData] (no new Firestore fields). [target] + [currentValue] drive the
/// progress bar for numeric goals; boolean goals leave them null.
class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final AchievementCategory category;
  final AchievementRarity rarity;

  /// Hidden achievements show as "???" until unlocked (a nice surprise).
  final bool hidden;

  /// Reward XP (cosmetic — surfaced on the card; not auto-awarded).
  final int rewardXp;

  /// Optional reward label (e.g. "Title: Monarch", "Badge", "Profile Border").
  final String? reward;

  /// Numeric target for a progress bar (null = boolean achievement).
  final num? target;

  /// Current numeric value for the progress bar (null = boolean achievement).
  final num Function(HunterData h)? currentValue;

  /// Whether the achievement is satisfied by the hunter's current stats.
  final bool Function(HunterData h) isDone;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.rarity,
    required this.isDone,
    this.hidden = false,
    this.rewardXp = 0,
    this.reward,
    this.target,
    this.currentValue,
  });

  /// Progress in [0, 1]. Returns 1 when done, else the numeric ratio (0 for
  /// boolean/untracked achievements that aren't done yet).
  double progressOf(HunterData h) {
    if (isDone(h)) return 1.0;
    if (target == null || currentValue == null) return 0.0;
    final t = target!.toDouble();
    if (t <= 0) return 0.0;
    return (currentValue!(h).toDouble() / t).clamp(0.0, 1.0);
  }
}

/// The resolved runtime status of an achievement for the current hunter.
class AchievementStatus {
  final Achievement achievement;
  final bool unlocked;
  final DateTime? unlockedAt;
  final double progress;

  const AchievementStatus({
    required this.achievement,
    required this.unlocked,
    required this.progress,
    this.unlockedAt,
  });
}

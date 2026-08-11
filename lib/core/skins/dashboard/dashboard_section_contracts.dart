import 'package:flutter/material.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Pure data contracts for each of the 5 Dashboard sections that skins can
/// restructure (Hero, Quest/Mission, Stats, Water, Quick Actions).
///
/// These classes carry EXACTLY the same values Basic/Pro/Max already pass
/// into their own section widgets today — no new fields, no new Firestore
/// reads, no gameplay/business logic. Their only purpose is to give every
/// skin's section widget (and the existing tier widgets) a single, shared
/// shape to be built from, so a skin component can never need to know
/// anything beyond what the tier screens already compute.

@immutable
class HeroSectionData {
  const HeroSectionData({
    required this.hunter,
    required this.rankTitle,
    required this.accentColor,
    this.onNotificationTap,
  });

  final HunterData hunter;
  final String rankTitle;

  /// Always `MembershipTheme.current.accent` at every call site — the one
  /// Premium Theme color token every skin component must use, so switching
  /// themes always repaints every skin's structure automatically.
  final Color accentColor;
  final VoidCallback? onNotificationTap;
}

@immutable
class QuestSectionData {
  const QuestSectionData({
    required this.todaySteps,
    this.goal = 10000,
  });

  final int todaySteps;
  final int goal;

  bool get isComplete => todaySteps >= goal;
  double get progress => (todaySteps / goal).clamp(0.0, 1.0);
}

@immutable
class StatsSectionData {
  const StatsSectionData({required this.stats});

  /// Reuses the existing [DashboardStat] model (already shared by Pro/Max)
  /// — a skin's Stats widget just renders whatever list its tier supplies,
  /// it never invents its own stat values.
  final List<DashboardStat> stats;
}

@immutable
class WaterSectionData {
  const WaterSectionData({
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.selectedCupSize,
    required this.onAdd,
    required this.onRemove,
    required this.onSetCupSize,
    required this.onEditGoal,
  });

  final int waterIntakeMl;
  final int waterGoalMl;
  final int selectedCupSize;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final ValueChanged<int> onSetCupSize;
  final VoidCallback onEditGoal;

  double get progress => (waterIntakeMl / waterGoalMl).clamp(0.0, 1.0);
}

/// One quick-action slot (Nutrition or Map). [isLocked]/[onTap] are always
/// resolved by the caller EXACTLY as today (Basic's existing
/// FeatureUnlockService checks + `_showUnlockDialog`; Pro/Max always
/// unlocked) — a skin's Quick Actions widget only decides how the two
/// slots are laid out, never whether they're locked.
@immutable
class QuickActionItem {
  const QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLocked = false,
  });

  final IconData icon;
  final String label;
  final bool isLocked;
  final VoidCallback onTap;
}

@immutable
class QuickActionsSectionData {
  const QuickActionsSectionData({
    required this.nutrition,
    required this.map,
  });

  final QuickActionItem nutrition;
  final QuickActionItem map;
}

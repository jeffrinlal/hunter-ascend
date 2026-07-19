import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stat_chip.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_mission_card.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_quick_actions.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_water_card.dart';

/// Premium Dashboard layout for Pro members.
///
/// Structurally distinct from the Basic dashboard: a large curved hero
/// (~38% of screen height) with a hunter avatar floating inside a large
/// animated XP ring that overlaps the hero's bottom edge, a horizontally
/// scrollable quick-actions row, floating stat chips, and redesigned
/// mission/water cards. All values (xp, level, steps, water, streak) are
/// passed in from the parent screen, which owns every Firestore
/// read/write and business-logic calculation — this widget only decides
/// how those values are laid out and styled.
class ProDashboardLayout extends StatelessWidget {
  final HunterData hunter;
  final int todaySteps;
  final int waterIntakeMl;
  final int waterGoalMl;
  final int selectedCupSize;
  final VoidCallback onAddWater;
  final VoidCallback onRemoveWater;
  final ValueChanged<int> onSetCupSize;
  final VoidCallback onEditWaterGoal;
  final VoidCallback onNutritionTap;
  final VoidCallback onMapTap;
  final VoidCallback? onNotificationTap;

  const ProDashboardLayout({
    super.key,
    required this.hunter,
    required this.todaySteps,
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.selectedCupSize,
    required this.onAddWater,
    required this.onRemoveWater,
    required this.onSetCupSize,
    required this.onEditWaterGoal,
    required this.onNutritionTap,
    required this.onMapTap,
    this.onNotificationTap,
  });

  String _rankTitle(int level) {
    if (level >= 30) return 'S RANK';
    if (level >= 20) return 'A RANK';
    if (level >= 15) return 'B RANK';
    if (level >= 10) return 'C RANK';
    if (level >= 5) return 'D RANK';
    return 'E RANK';
  }

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.gold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EntranceFadeSlide(
          child: _PremiumHero(
            hunter: hunter,
            accent: accent,
            rankTitle: _rankTitle(hunter.level),
            onNotificationTap: onNotificationTap,
          ),
        ),
        const SizedBox(height: 52), // Reserves space for the floating avatar/ring overlap.

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 90),
          child: PremiumQuickActions(onNutritionTap: onNutritionTap, onMapTap: onMapTap),
        ),
        const SizedBox(height: 20),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 140),
          child: Text(
            "TODAY'S PROGRESS",
            style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
        ),
        const SizedBox(height: 12),
        EntranceFadeSlide(
          delay: const Duration(milliseconds: 160),
          child: DashboardStatChipRow(
            stats: [
              DashboardStat(label: 'Steps', value: '$todaySteps', icon: Icons.directions_walk_rounded, color: HunterTheme.primary),
              DashboardStat(label: 'Streak', value: '${hunter.streak}d', icon: Icons.local_fire_department_rounded, color: Colors.orange),
              DashboardStat(label: 'Daily XP', value: '${hunter.dailyXp}', icon: Icons.bolt_rounded, color: HunterTheme.gold),
              DashboardStat(label: 'Water', value: '${(waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: Colors.cyan),
            ],
          ),
        ),
        const SizedBox(height: 20),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 200),
          child: PremiumMissionCard(steps: todaySteps),
        ),
        const SizedBox(height: 16),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 240),
          child: PremiumWaterCard(
            waterIntakeMl: waterIntakeMl,
            waterGoalMl: waterGoalMl,
            selectedCupSize: selectedCupSize,
            onAdd: onAddWater,
            onRemove: onRemoveWater,
            onSetCupSize: onSetCupSize,
            onEditGoal: onEditWaterGoal,
          ),
        ),
      ],
    );
  }
}

/// Large curved premium hero (~38% of screen height) with the hunter's
/// avatar floating inside a large animated XP ring that overlaps the
/// hero's rounded bottom edge.
class _PremiumHero extends StatelessWidget {
  final HunterData hunter;
  final Color accent;
  final String rankTitle;
  final VoidCallback? onNotificationTap;

  const _PremiumHero({
    required this.hunter,
    required this.accent,
    required this.rankTitle,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBytes = hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty
        ? base64Decode(hunter.profilePicture!)
        : null;
    final heroHeight = MediaQuery.of(context).size.height * 0.36;
    final hasNotif = (hunter.notificationTime ?? '').isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          height: heroHeight,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(48),
              bottomRight: Radius.circular(48),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withOpacity(0.85),
                HunterTheme.primary.withOpacity(0.75),
              ],
            ),
            boxShadow: [
              BoxShadow(color: accent.withOpacity(0.35), blurRadius: 30, offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                    ),
                    child: const Text(
                      'PRO MEMBER',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.4),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onNotificationTap,
                    child: Icon(
                      hasNotif ? Icons.notifications_active : Icons.notifications_none,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    rankTitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'LEVEL ${hunter.level}',
                style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
              ),
              Text(
                hunter.hunterName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -46,
          child: SizedBox(
            width: 128,
            height: 128,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedXpRing(xp: hunter.xp, level: hunter.level, size: 128, accentColor: accent),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HunterTheme.cardColor,
                    border: Border.all(color: accent, width: 2.5),
                  ),
                  child: avatarBytes != null
                      ? ClipOval(child: Image.memory(avatarBytes, fit: BoxFit.cover, width: 84, height: 84))
                      : Center(child: Icon(Icons.person, color: accent, size: 40)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

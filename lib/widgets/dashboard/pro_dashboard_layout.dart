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

// ── Hero layout constants ─────────────────────────────────────────────────
// Kept in one place so the floating avatar/ring, the hero's reserved bottom
// space, and the gap the parent leaves below the hero always stay in sync.
const double _kProRingSize = 128;
const double _kProAvatarSize = 84;

/// How far the ring dips *below* the hero's bottom edge.
const double _kProAvatarOverhang = 46;

/// Portion of the ring that sits *inside* the hero. The hero reserves this
/// much bottom padding so its text can never render under the ring/avatar.
const double _kProRingInsideHero = _kProRingSize - _kProAvatarOverhang;

/// Vertical breathing room between the hero text and the ring, and between
/// the overhanging ring and the first section below the hero.
const double _kProHeroGap = 12;

/// Premium Dashboard layout for Pro members.
///
/// Structurally distinct from the Basic dashboard: a large curved hero with a
/// hunter avatar floating inside a large animated XP ring that overlaps the
/// hero's rounded bottom edge, a horizontally scrollable quick-actions row,
/// floating stat chips, and redesigned mission/water cards. All values (xp,
/// level, steps, water, streak) are passed in from the parent screen, which
/// owns every Firestore read/write and business-logic calculation — this
/// widget only decides how those values are laid out and styled.
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
        // Clears the ring that overhangs the hero's bottom edge.
        const SizedBox(height: _kProAvatarOverhang + _kProHeroGap),

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

/// Curved premium hero with the hunter's avatar floating inside a large
/// animated XP ring that overlaps the hero's rounded bottom edge.
///
/// The hero is content-driven (no fixed height) so it can never overflow at
/// any text scale. Its bottom padding reserves [_kProRingInsideHero] so the
/// rank/level/name text always sits *above* the ring — text and avatar never
/// overlap.
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
    final hasNotif = (hunter.notificationTime ?? '').isNotEmpty;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: 18,
            left: 22,
            right: 22,
            bottom: _kProRingInsideHero + _kProHeroGap,
          ),
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
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 28),
              Row(
                children: [
                  const Icon(Icons.military_tech_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      rankTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // FittedBox guards against overflow from very high levels or
              // large system text scales.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'LEVEL ${hunter.level}',
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                hunter.hunterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: -_kProAvatarOverhang,
          child: SizedBox(
            width: _kProRingSize,
            height: _kProRingSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedXpRing(
                  xp: hunter.xp,
                  level: hunter.level,
                  size: _kProRingSize,
                  showLabel: false,
                  accentColor: accent,
                ),
                Container(
                  width: _kProAvatarSize,
                  height: _kProAvatarSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: HunterTheme.cardColor,
                    border: Border.all(color: accent, width: 2.5),
                  ),
                  child: avatarBytes != null
                      ? ClipOval(child: Image.memory(avatarBytes, fit: BoxFit.cover, width: _kProAvatarSize, height: _kProAvatarSize))
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

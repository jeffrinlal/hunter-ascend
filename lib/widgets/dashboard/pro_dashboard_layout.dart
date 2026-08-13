import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stat_chip.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_mission_card.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_quick_actions.dart';
import 'package:hunter_ascend/widgets/dashboard/premium_water_card.dart';
import 'package:hunter_ascend/widgets/dashboard/shop_highlight_button.dart';
import 'package:hunter_ascend/screens/shop/coin_shop_screen.dart';
import 'package:hunter_ascend/screens/nutrition/nutrition_screen.dart';
import 'package:hunter_ascend/screens/map/map_screen.dart';

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

  // Rank title resolved via the centralized RankService (single source of truth).
  String _rankTitle(int level) => RankService.instance.shortTitleForLevel(level);

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.gold;

    // Phase 3 (revised): each section is wrapped in its Skin*Section
    // resolver, passing Pro's own existing widget as `fallback`. When no
    // skin is active (the default), every resolver renders `fallback`
    // completely unmodified — byte-for-byte identical to Pro's UI before
    // this change. Only when a non-classic skin is the active appearance
    // does a genuinely different, skin-specific widget replace it — and it
    // is IDENTICAL to the widget a Basic or Max user with the same skin
    // would see, since skin identity is resolved independently of tier.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Membership identity + Coin Shop entry, OUTSIDE the skinnable hero.
        //
        // Renders nothing (zero height) unless a skin owns the hero, so Pro's
        // existing no-skin appearance is completely unchanged — the badge and
        // Shop pill keep coming from `_PremiumHero` in that case. See
        // [_MembershipShopStrip].
        const _MembershipShopStrip(label: 'PRO MEMBER'),

        EntranceFadeSlide(
          child: SkinHeroSection(
            data: HeroSectionData(
              hunter: hunter,
              rankTitle: _rankTitle(hunter.level),
              accentColor: MembershipTheme.current.accent,
              onNotificationTap: onNotificationTap,
            ),
            fallback: _PremiumHero(
              hunter: hunter,
              accent: accent,
              rankTitle: _rankTitle(hunter.level),
              onNotificationTap: onNotificationTap,
            ),
          ),
        ),
        // Clears the ring that overhangs the hero's bottom edge.
        const SizedBox(height: _kProAvatarOverhang + _kProHeroGap),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 90),
          child: SkinQuickActionsSection(
            data: QuickActionsSectionData(
              nutrition: QuickActionItem(icon: Icons.restaurant_menu_rounded, label: 'Nutrition', onTap: onNutritionTap),
              map: QuickActionItem(icon: Icons.map_rounded, label: 'Map', onTap: onMapTap),
            ),
            fallback: PremiumQuickActions(onNutritionTap: onNutritionTap, onMapTap: onMapTap),
          ),
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
          child: SkinStatsSection(
            data: StatsSectionData(stats: [
              DashboardStat(label: 'Steps', value: '$todaySteps', icon: Icons.directions_walk_rounded, color: HunterTheme.primary),
              DashboardStat(label: 'Streak', value: '${hunter.streak}d', icon: Icons.local_fire_department_rounded, color: Colors.orange),
              DashboardStat(label: 'Daily XP', value: '${hunter.dailyXp}', icon: Icons.bolt_rounded, color: HunterTheme.gold),
              DashboardStat(label: 'Water', value: '${(waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: Colors.cyan),
            ]),
            fallback: DashboardStatChipRow(
              stats: [
                DashboardStat(label: 'Steps', value: '$todaySteps', icon: Icons.directions_walk_rounded, color: HunterTheme.primary),
                DashboardStat(label: 'Streak', value: '${hunter.streak}d', icon: Icons.local_fire_department_rounded, color: Colors.orange),
                DashboardStat(label: 'Daily XP', value: '${hunter.dailyXp}', icon: Icons.bolt_rounded, color: HunterTheme.gold),
                DashboardStat(label: 'Water', value: '${(waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: Colors.cyan),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 200),
          child: SkinQuestSection(
            data: QuestSectionData(todaySteps: todaySteps),
            fallback: PremiumMissionCard(steps: todaySteps),
          ),
        ),
        const SizedBox(height: 16),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 240),
          child: SkinWaterSection(
            data: WaterSectionData(
              waterIntakeMl: waterIntakeMl,
              waterGoalMl: waterGoalMl,
              selectedCupSize: selectedCupSize,
              onAdd: onAddWater,
              onRemove: onRemoveWater,
              onSetCupSize: onSetCupSize,
              onEditGoal: onEditWaterGoal,
            ),
            fallback: PremiumWaterCard(
              waterIntakeMl: waterIntakeMl,
              waterGoalMl: waterGoalMl,
              selectedCupSize: selectedCupSize,
              onAdd: onAddWater,
              onRemove: onRemoveWater,
              onSetCupSize: onSetCupSize,
              onEditGoal: onEditWaterGoal,
            ),
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
                  // Coin Shop button
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CoinShopScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text('🪙', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 5),
                          Text(
                            'Shop',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
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


/// Membership identity + Coin Shop entry, rendered ONLY while a skin is the
/// active appearance.
///
/// ── Why this exists ──
/// Pro's `PRO MEMBER` badge and its Coin Shop pill live inside [_PremiumHero].
/// `SkinHeroSection` replaces that entire fallback widget when a skin is
/// active, so both used to disappear — a membership CAPABILITY (reaching the
/// Coin Shop) and the tier's identity were being lost to a purely
/// PRESENTATIONAL swap. Membership and skins are independent systems, so a
/// skin must never remove Pro functionality.
///
/// ── How it behaves ──
///   * No skin active  → returns `SizedBox.shrink()`. Zero height, zero
///     spacing, so Pro's existing layout is byte-for-byte what it was; the
///     badge and Shop pill still come from `_PremiumHero` as before.
///   * Skin active      → the skin owns the hero, and this compact strip
///     carries the tier identity and the Shop entry instead.
///
/// The two states are mutually exclusive, so there is ALWAYS exactly one Shop
/// button on screen — never two, never zero. No skin file is touched and no
/// skin has any knowledge of the Shop.
///
/// Styling uses the live membership accent rather than the hero's white-on-
/// gradient treatment, because outside the hero there is no gradient to read
/// against. That keeps the tier visually distinct from Basic.
class _MembershipShopStrip extends StatelessWidget {
  const _MembershipShopStrip({required this.label});

  /// Tier identity text, e.g. `PRO MEMBER`.
  final String label;

  @override
  Widget build(BuildContext context) {
    // Same skin-active predicate the rest of the dashboard uses
    // (`appearanceActive && activeSkin != classic`), read from the existing
    // public notifiers. No new listener, no Firestore, no service changes.
    return ValueListenableBuilder<SkinId>(
      valueListenable: SkinService.instance.activeSkinNotifier,
      builder: (context, activeSkin, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SkinService.instance.skinAppearanceActiveNotifier,
          builder: (context, appearanceActive, __) {
            final skinActive =
                appearanceActive && activeSkin != SkinId.classic;
            if (!skinActive) return const SizedBox.shrink();

            final accent = MembershipTheme.current.accent;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  // ── Tier identity ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withOpacity(0.45)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // ── Coin Shop entry (same destination as the hero's) ──
                  ShopHighlightButton(
                    accentColor: accent,
                    emojiSize: 14,
                    textSize: 12,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

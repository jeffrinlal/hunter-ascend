import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_id.dart';
import 'package:hunter_ascend/core/skins/skin_service.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/dashboard/achievement_highlight.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/daily_overview_timeline.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_mission_card.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_quick_actions.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_water_card.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';
import 'package:hunter_ascend/widgets/dashboard/shop_highlight_button.dart';
import 'package:hunter_ascend/screens/shop/coin_shop_screen.dart';

/// Elite Dashboard layout for Max members.
///
/// Structurally distinct from both the Basic dashboard and the Pro
/// dashboard: a full-width immersive hero banner (no rounded curve — bleeds
/// edge-to-edge) with an animated glowing particle background sitting
/// *behind* a huge centered XP ring + Level/Rank/XP banner text, an
/// achievement-highlight carousel, a vertical "Daily Overview" timeline
/// (instead of Pro's floating chips or Basic's grid), and neon-bordered
/// mission/water/quick-action cards. Every value below is supplied by the
/// parent screen (HunterData + already-streamed water/step state) — this
/// widget performs no Firestore reads/writes and duplicates no business
/// logic.
class MaxDashboardLayout extends StatefulWidget {
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

  const MaxDashboardLayout({
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

  @override
  State<MaxDashboardLayout> createState() => _MaxDashboardLayoutState();
}

class _MaxDashboardLayoutState extends State<MaxDashboardLayout>
    with SingleTickerProviderStateMixin {
  late final AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  // Rank still comes entirely from the centralized RankService. The Max hero
  // shows the rank's premium COSMETIC title (e.g. "SHADOW MONARCH" for rank S)
  // — an alternate visual presentation of the same canonical rank, not a
  // separate rank calculation.
  String _rankTitle(int level) => RankService.instance.displayTitleForLevel(level);

  @override
  Widget build(BuildContext context) {
    final hunter = widget.hunter;
    final accent = HunterTheme.purple;

    // Phase 3 (revised): each section is wrapped in its Skin*Section
    // resolver, passing Max's own existing widget as `fallback`. When no
    // skin is active (the default), every resolver renders `fallback`
    // completely unmodified — byte-for-byte identical to Max's UI before
    // this change. Only when a non-classic skin is the active appearance
    // does a genuinely different, skin-specific widget replace it — and it
    // is IDENTICAL to the widget a Basic or Pro user with the same skin
    // would see, since skin identity is resolved independently of tier.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Membership identity + Coin Shop entry, OUTSIDE the skinnable hero.
        //
        // Renders nothing (zero height) unless a skin owns the hero, so Max's
        // existing no-skin appearance is completely unchanged — the badge and
        // Shop pill keep coming from `_EliteHeroBanner` in that case. See
        // [_MembershipShopStrip].
        const _MembershipShopStrip(label: 'MAX \u2022 ELITE HUNTER'),

        // ── Immersive hero banner (fully rounded, symmetric margins). ──
        SkinHeroSection(
          data: HeroSectionData(
            hunter: hunter,
            rankTitle: _rankTitle(hunter.level),
            accentColor: MembershipTheme.current.accent,
            onNotificationTap: widget.onNotificationTap,
          ),
          fallback: _EliteHeroBanner(
            hunter: hunter,
            accent: accent,
            rankTitle: _rankTitle(hunter.level),
            particleController: _particleController,
            onNotificationTap: widget.onNotificationTap,
          ),
        ),
        const SizedBox(height: 22),

        EntranceFadeSlide(
          child: AchievementHighlightRow(
            duelWins: hunter.duelWins,
            questsDone: hunter.questsDone,
            streak: hunter.streak,
          ),
        ),
        const SizedBox(height: 22),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 80),
          child: SkinQuickActionsSection(
            data: QuickActionsSectionData(
              nutrition: QuickActionItem(icon: Icons.restaurant_menu_rounded, label: 'Nutrition', onTap: widget.onNutritionTap),
              map: QuickActionItem(icon: Icons.map_rounded, label: 'Map', onTap: widget.onMapTap),
            ),
            fallback: EliteQuickActions(onNutritionTap: widget.onNutritionTap, onMapTap: widget.onMapTap),
          ),
        ),
        const SizedBox(height: 22),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 120),
          child: Row(
            children: [
              Icon(Icons.timeline_rounded, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                'DAILY OVERVIEW',
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        EntranceFadeSlide(
          delay: const Duration(milliseconds: 150),
          child: SkinStatsSection(
            data: StatsSectionData(stats: [
              DashboardStat(label: "Today's XP", value: '${hunter.dailyXp}', icon: Icons.bolt_rounded, color: HunterTheme.gold),
              DashboardStat(label: 'Steps', value: '${widget.todaySteps}', icon: Icons.directions_walk_rounded, color: HunterTheme.primary),
              DashboardStat(label: 'Active Streak', value: '${hunter.streak} days', icon: Icons.local_fire_department_rounded, color: Colors.orange),
              DashboardStat(label: 'Water', value: '${(widget.waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: HunterTheme.purpleLight),
            ]),
            fallback: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: HunterTheme.cardColor,
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: DailyOverviewTimeline(
                stats: [
                  DashboardStat(label: "Today's XP", value: '${hunter.dailyXp}', icon: Icons.bolt_rounded, color: HunterTheme.gold),
                  DashboardStat(label: 'Steps', value: '${widget.todaySteps}', icon: Icons.directions_walk_rounded, color: HunterTheme.primary),
                  DashboardStat(label: 'Active Streak', value: '${hunter.streak} days', icon: Icons.local_fire_department_rounded, color: Colors.orange),
                  DashboardStat(label: 'Water', value: '${(widget.waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: HunterTheme.purpleLight),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 190),
          child: SkinQuestSection(
            data: QuestSectionData(todaySteps: widget.todaySteps),
            fallback: EliteMissionCard(steps: widget.todaySteps),
          ),
        ),
        const SizedBox(height: 16),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 230),
          child: SkinWaterSection(
            data: WaterSectionData(
              waterIntakeMl: widget.waterIntakeMl,
              waterGoalMl: widget.waterGoalMl,
              selectedCupSize: widget.selectedCupSize,
              onAdd: widget.onAddWater,
              onRemove: widget.onRemoveWater,
              onSetCupSize: widget.onSetCupSize,
              onEditGoal: widget.onEditWaterGoal,
            ),
            fallback: EliteWaterCard(
              waterIntakeMl: widget.waterIntakeMl,
              waterGoalMl: widget.waterGoalMl,
              selectedCupSize: widget.selectedCupSize,
              onAdd: widget.onAddWater,
              onRemove: widget.onRemoveWater,
              onSetCupSize: widget.onSetCupSize,
              onEditGoal: widget.onEditWaterGoal,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width immersive hero banner: animated particle background behind a
/// huge centered XP ring with Level/Rank/XP text underneath. Edge-to-edge
/// (no rounded corners), unlike Pro's curved, bottom-rounded hero.
class _EliteHeroBanner extends StatelessWidget {
  final HunterData hunter;
  final Color accent;
  final String rankTitle;
  final AnimationController particleController;
  final VoidCallback? onNotificationTap;

  const _EliteHeroBanner({
    required this.hunter,
    required this.accent,
    required this.rankTitle,
    required this.particleController,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBytes = hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty
        ? base64Decode(hunter.profilePicture!)
        : null;
    final hasNotif = (hunter.notificationTime ?? '').isNotEmpty;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0B2E),
            accent.withOpacity(0.35),
            HunterTheme.cardColor,
          ],
        ),
        border: Border.all(color: accent.withOpacity(0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.22), blurRadius: 24, spreadRadius: 1),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: particleController,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(progress: particleController.value, color: accent),
              ),
            ),
          ),
          Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, Colors.pinkAccent.withOpacity(0.7)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MAX \u2022 ELITE HUNTER',
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
              const SizedBox(height: 18),
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedXpRing(xp: hunter.xp, level: hunter.level, size: 168, showGlow: true, showLabel: false, accentColor: accent),
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HunterTheme.cardColor,
                        border: Border.all(color: accent, width: 2.5),
                      ),
                      child: avatarBytes != null
                          ? ClipOval(child: Image.memory(avatarBytes, fit: BoxFit.cover, width: 96, height: 96))
                          : Center(child: Icon(Icons.person, color: accent, size: 44)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                hunter.hunterName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                rankTitle,
                style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 4),
              Text(
                '${hunter.xp} / 500 XP  \u2022  Level ${hunter.level}',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lightweight animated particle painter for the Max elite hero.
class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static final List<_Particle> _particles = _generate();

  static List<_Particle> _generate() {
    final rng = math.Random(99);
    return List.generate(18, (_) => _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.5 + rng.nextDouble() * 2.5,
      speed: 0.3 + rng.nextDouble() * 0.7,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final y = (p.y + progress * p.speed) % 1.0;
      final opacity = (1.0 - (y * 2 - 1).abs()) * 0.5;
      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 0.5))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}

class _Particle {
  const _Particle({required this.x, required this.y, required this.size, required this.speed});
  final double x, y, size, speed;
}


/// Membership identity + Coin Shop entry, rendered ONLY while a skin is the
/// active appearance.
///
/// ── Why this exists ──
/// Max's `MAX • ELITE HUNTER` badge and its Coin Shop pill live inside
/// [_EliteHeroBanner]. `SkinHeroSection` replaces that entire fallback widget
/// when a skin is active, so both used to disappear — a membership CAPABILITY
/// (reaching the Coin Shop) and the tier's identity were being lost to a
/// purely PRESENTATIONAL swap. Membership and skins are independent systems,
/// so a skin must never remove Max functionality.
///
/// ── How it behaves ──
///   * No skin active  → returns `SizedBox.shrink()`. Zero height, zero
///     spacing, so Max's existing layout is byte-for-byte what it was; the
///     badge and Shop pill still come from `_EliteHeroBanner` as before.
///   * Skin active      → the skin owns the hero, and this compact strip
///     carries the tier identity and the Shop entry instead.
///
/// The two states are mutually exclusive, so there is ALWAYS exactly one Shop
/// button on screen — never two, never zero. No skin file is touched and no
/// skin has any knowledge of the Shop.
///
/// Styling uses the live membership accent rather than the banner's white-on-
/// gradient treatment, because outside the banner there is no gradient to read
/// against. That keeps the tier visually distinct from Basic.
class _MembershipShopStrip extends StatelessWidget {
  const _MembershipShopStrip({required this.label});

  /// Tier identity text, e.g. `MAX • ELITE HUNTER`.
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
                  Flexible(
                    child: Container(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // ── Coin Shop entry (same destination as the banner's) ──
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

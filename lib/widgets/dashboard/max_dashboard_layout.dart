import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/dashboard/achievement_highlight.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/daily_overview_timeline.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_mission_card.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_quick_actions.dart';
import 'package:hunter_ascend/widgets/dashboard/elite_water_card.dart';
import 'package:hunter_ascend/widgets/dashboard/entrance_fade_slide.dart';

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

  String _rankTitle(int level) {
    if (level >= 30) return 'SHADOW MONARCH';
    if (level >= 20) return 'S-RANK HUNTER';
    if (level >= 15) return 'ELITE HUNTER';
    if (level >= 10) return 'A-RANK HUNTER';
    if (level >= 5) return 'HUNTER';
    return 'RECRUIT';
  }

  @override
  Widget build(BuildContext context) {
    final hunter = widget.hunter;
    final accent = HunterTheme.purple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Full-width immersive hero (edge-to-edge, negative horizontal margin
        // to counter the parent's SingleChildScrollView padding). ──
        LayoutBuilder(
          builder: (context, constraints) => Transform.translate(
            offset: const Offset(-16, 0),
            child: SizedBox(
              width: constraints.maxWidth + 32,
              child: _EliteHeroBanner(
                hunter: hunter,
                accent: accent,
                rankTitle: _rankTitle(hunter.level),
                particleController: _particleController,
                onNotificationTap: widget.onNotificationTap,
              ),
            ),
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
          child: EliteQuickActions(onNutritionTap: widget.onNutritionTap, onMapTap: widget.onMapTap),
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
          child: Container(
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
                DashboardStat(label: 'Water', value: '${(widget.waterIntakeMl / 1000).toStringAsFixed(1)}L', icon: Icons.water_drop_rounded, color: Colors.cyan),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 190),
          child: EliteMissionCard(steps: widget.todaySteps),
        ),
        const SizedBox(height: 16),

        EntranceFadeSlide(
          delay: const Duration(milliseconds: 230),
          child: EliteWaterCard(
            waterIntakeMl: widget.waterIntakeMl,
            waterGoalMl: widget.waterGoalMl,
            selectedCupSize: widget.selectedCupSize,
            onAdd: widget.onAddWater,
            onRemove: widget.onRemoveWater,
            onSetCupSize: widget.onSetCupSize,
            onEditGoal: widget.onEditWaterGoal,
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0B2E),
            accent.withOpacity(0.35),
            HunterTheme.cardColor,
          ],
        ),
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
              const SizedBox(height: 18),
              SizedBox(
                width: 168,
                height: 168,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedXpRing(xp: hunter.xp, level: hunter.level, size: 168, showGlow: true, accentColor: accent),
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
                overflow: TextOverflow.ellipsis,
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

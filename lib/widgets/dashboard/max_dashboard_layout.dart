import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/data/models/hunter_data.dart';
import 'package:hunter_ascend/widgets/dashboard/animated_xp_ring.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';
import 'package:hunter_ascend/widgets/dashboard/steps_card.dart';
import 'package:hunter_ascend/widgets/glass/glass_card.dart';

/// Elite Dashboard layout for Max members.
///
/// Includes everything in Pro plus: larger immersive hero, animated particles,
/// elite title styling, advanced XP ring with glow, daily overview, elite
/// stat cards, richer transitions and spacing.
class MaxDashboardLayout extends StatefulWidget {
  final HunterData hunter;
  final int todaySteps;
  final int waterIntakeMl;
  final int waterGoalMl;
  final Widget quickActions;
  final Widget waterCard;
  final VoidCallback? onNotificationTap;

  const MaxDashboardLayout({
    super.key,
    required this.hunter,
    required this.todaySteps,
    required this.waterIntakeMl,
    required this.waterGoalMl,
    required this.quickActions,
    required this.waterCard,
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
    if (level >= 5)  return 'HUNTER';
    return 'RECRUIT';
  }

  @override
  Widget build(BuildContext context) {
    final hunter = widget.hunter;
    final accent = HunterTheme.purple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Bar (notification) ──
        _MaxTopBar(hunter: hunter, onNotificationTap: widget.onNotificationTap),
        const SizedBox(height: 16),

        // ── Elite Hero Section ──
        _EliteHero(
          hunter: hunter,
          accent: accent,
          particleController: _particleController,
        ),
        const SizedBox(height: 28),

        // ── XP Progress with Glow ──
        Center(
          child: AnimatedXpRing(
            xp: hunter.xp,
            level: hunter.level,
            size: 140,
            showGlow: true,
            accentColor: accent,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _rankTitle(hunter.level),
            style: TextStyle(
              color: accent,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            '${hunter.xp} / 500 XP to Level ${hunter.level + 1}',
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 28),

        // ── Daily Overview Section ──
        Text(
          'DAILY OVERVIEW',
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 14),
        DashboardStatsGrid(
          stats: [
            DashboardStat(
              label: "Today's XP",
              value: '${hunter.dailyXp}',
              icon: Icons.bolt_rounded,
              color: HunterTheme.gold,
            ),
            DashboardStat(
              label: 'Steps',
              value: '${widget.todaySteps}',
              icon: Icons.directions_walk_rounded,
              color: HunterTheme.primary,
            ),
            DashboardStat(
              label: 'Streak',
              value: '${hunter.streak} days',
              icon: Icons.local_fire_department_rounded,
              color: Colors.orange,
            ),
            DashboardStat(
              label: 'Water',
              value: '${(widget.waterIntakeMl / 1000).toStringAsFixed(1)}L',
              icon: Icons.water_drop_rounded,
              color: Colors.cyan,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Steps Card ──
        StepsCard(steps: widget.todaySteps),
        const SizedBox(height: 20),

        // ── Quick Actions ──
        widget.quickActions,
        const SizedBox(height: 20),

        // ── Water Card ──
        widget.waterCard,
      ],
    );
  }
}

/// Elite hero section with animated particle background and MAX badge.
class _EliteHero extends StatelessWidget {
  final HunterData hunter;
  final Color accent;
  final AnimationController particleController;

  const _EliteHero({
    required this.hunter,
    required this.accent,
    required this.particleController,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBytes = hunter.profilePicture != null && hunter.profilePicture!.isNotEmpty
        ? base64Decode(hunter.profilePicture!)
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(0.15),
            HunterTheme.cardColor,
            accent.withOpacity(0.08),
          ],
        ),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.12),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Animated particles
          Positioned.fill(
            child: AnimatedBuilder(
              animation: particleController,
              builder: (context, _) => CustomPaint(
                painter: _ParticlePainter(
                  progress: particleController.value,
                  color: accent,
                ),
              ),
            ),
          ),
          // Content
          Row(
            children: [
              // Avatar with animated glow
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 3),
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(0.4), blurRadius: 16, spreadRadius: 2),
                  ],
                ),
                child: avatarBytes != null
                    ? ClipOval(child: Image.memory(avatarBytes, fit: BoxFit.cover, width: 72, height: 72))
                    : Center(child: Icon(Icons.person, color: accent, size: 36)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hunter.hunterName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: HunterTheme.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [accent, accent.withOpacity(0.7)]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MAX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${hunter.streak} day streak',
                          style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.emoji_events_rounded, color: HunterTheme.gold, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${hunter.questsDone} quests',
                          style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
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
    return List.generate(12, (_) => _Particle(
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
      final opacity = (1.0 - (y * 2 - 1).abs()) * 0.4;
      final paint = Paint()
        ..color = color.withOpacity(opacity.clamp(0.0, 0.4))
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


/// Top bar with notification icon for Max layout.
class _MaxTopBar extends StatelessWidget {
  final HunterData hunter;
  final VoidCallback? onNotificationTap;

  const _MaxTopBar({required this.hunter, this.onNotificationTap});

  @override
  Widget build(BuildContext context) {
    final hasNotif = (hunter.notificationTime ?? '').isNotEmpty;

    return Row(
      children: [
        GestureDetector(
          onTap: onNotificationTap,
          child: Stack(
            children: [
              Icon(
                hasNotif ? Icons.notifications_active : Icons.notifications_none,
                color: hasNotif ? HunterTheme.purple : HunterTheme.textSecondary,
                size: 24,
              ),
              if (hasNotif)
                Positioned(
                  right: 0, top: 0,
                  child: Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      color: HunterTheme.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_fire_department, color: Colors.orange, size: 22),
          const SizedBox(width: 3),
          Text(
            '${hunter.streak}',
            style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ]),
      ],
    );
  }
}

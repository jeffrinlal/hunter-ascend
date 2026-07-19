import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/milestone_service.dart';

/// Full celebration dialog with icon, glow, confetti, and motivational text.
///
/// Designed to be shown via [MilestoneService.show] — not instantiated directly.
class MilestoneCelebrationDialog extends StatefulWidget {
  final MilestoneData data;

  const MilestoneCelebrationDialog({super.key, required this.data});

  @override
  State<MilestoneCelebrationDialog> createState() =>
      _MilestoneCelebrationDialogState();
}

class _MilestoneCelebrationDialogState extends State<MilestoneCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();

    // Haptic feedback on celebration.
    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Color _accentColor() {
    switch (widget.data.type) {
      case MilestoneType.steps:
        return HunterTheme.primary;
      case MilestoneType.quest:
        return HunterTheme.success;
      case MilestoneType.levelUp:
        return HunterTheme.gold;
      case MilestoneType.streak:
        return Colors.orange;
      case MilestoneType.duelVictory:
        return HunterTheme.dangerAlt;
      case MilestoneType.rank:
        return HunterTheme.purple;
      case MilestoneType.sleep:
        return const Color(0xFF6C63FF);
      case MilestoneType.custom:
        return HunterTheme.primary;
    }
  }

  IconData _defaultIcon() {
    switch (widget.data.type) {
      case MilestoneType.steps:
        return Icons.directions_walk_rounded;
      case MilestoneType.quest:
        return Icons.task_alt_rounded;
      case MilestoneType.levelUp:
        return Icons.trending_up_rounded;
      case MilestoneType.streak:
        return Icons.local_fire_department_rounded;
      case MilestoneType.duelVictory:
        return Icons.emoji_events_rounded;
      case MilestoneType.rank:
        return Icons.military_tech_rounded;
      case MilestoneType.sleep:
        return Icons.nights_stay_rounded;
      case MilestoneType.custom:
        return Icons.star_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accentColor();
    final icon = widget.data.icon ?? _defaultIcon();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Confetti layer ──
          AnimatedBuilder(
            animation: _confettiController,
            builder: (context, _) => CustomPaint(
              size: const Size(320, 400),
              painter: _ConfettiPainter(
                progress: _confettiController.value,
                accent: accent,
              ),
            ),
          ),

          // ── Dialog card ──
          Container(
            width: 300,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: accent.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(0.2),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon with glow ──
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withOpacity(0.12),
                    border: Border.all(color: accent.withOpacity(0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(icon, color: accent, size: 40),
                ),
                const SizedBox(height: 24),

                // ── Title ──
                Text(
                  widget.data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 10),

                // ── Subtitle ──
                Text(
                  widget.data.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HunterTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                // ── XP reward ──
                if (widget.data.xp != null && widget.data.xp! > 0) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: HunterTheme.success.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HunterTheme.success.withOpacity(0.3)),
                    ),
                    child: Text(
                      '+${widget.data.xp} XP',
                      style: TextStyle(
                        color: HunterTheme.success,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ── Continue button ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: accent.withOpacity(0.4),
                    ),
                    child: const Text(
                      'CONTINUE',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight confetti burst painter.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.accent});

  final double progress;
  final Color accent;

  static final List<_Particle> _particles = _generateParticles();

  static List<_Particle> _generateParticles() {
    final rng = math.Random(12345);
    final colors = [
      Colors.amber,
      Colors.orange,
      Colors.pink,
      Colors.cyan,
      Colors.lightGreen,
      Colors.purple,
    ];

    return List.generate(30, (i) => _Particle(
      angle: rng.nextDouble() * math.pi * 2,
      speed: 80 + rng.nextDouble() * 120,
      size: 4 + rng.nextDouble() * 5,
      color: colors[i % colors.length],
      rotationSpeed: (rng.nextDouble() - 0.5) * 6,
    ));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2 - 20);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);

    for (final p in _particles) {
      final distance = p.speed * progress;
      final gravity = 80 * progress * progress;
      final dx = center.dx + math.cos(p.angle) * distance;
      final dy = center.dy + math.sin(p.angle) * distance + gravity;

      final paint = Paint()
        ..color = p.color.withOpacity(opacity * 0.8)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.rotationSpeed * progress * math.pi);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
    required this.rotationSpeed,
  });

  final double angle;
  final double speed;
  final double size;
  final Color color;
  final double rotationSpeed;
}

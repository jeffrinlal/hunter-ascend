import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Premium visual decorator for leaderboard cards.
///
/// Wraps any card [child] with premium styling based on [membership] tier:
/// - Basic: no decoration (passes through unchanged).
/// - Pro: metallic gold gradient background, gold border, gold glow,
///   rotating energy ring, occasional sparkle particles.
/// - Max: purple+gold metallic gradient, stronger glow, rotating ring,
///   shimmer sweep effect, premium particles.
///
/// Performance:
/// - Only Pro/Max cards animate (Basic passes through with zero overhead).
/// - Uses RepaintBoundary to isolate animation repaints.
/// - Single AnimationController drives all effects.
class PremiumCardDecorator extends StatelessWidget {
  final String membership;
  final Widget child;
  final BorderRadius borderRadius;

  const PremiumCardDecorator({
    super.key,
    required this.membership,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    final tier = MembershipTier.fromString(membership);
    if (tier == MembershipTier.basic) return child;

    return _AnimatedPremiumCard(
      tier: tier,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

class _AnimatedPremiumCard extends StatefulWidget {
  final MembershipTier tier;
  final Widget child;
  final BorderRadius borderRadius;

  const _AnimatedPremiumCard({
    required this.tier,
    required this.child,
    required this.borderRadius,
  });

  @override
  State<_AnimatedPremiumCard> createState() => _AnimatedPremiumCardState();
}

class _AnimatedPremiumCardState extends State<_AnimatedPremiumCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isMax => widget.tier == MembershipTier.max;

  // ── Color configurations ──────────────────────────────────────────────

  List<Color> get _gradientColors => _isMax
      ? [
          const Color(0xFF1A0A2E), // deep purple
          const Color(0xFF2D1B4E), // royal purple
          const Color(0xFF1A1400), // dark gold
          const Color(0xFF2D1B4E), // royal purple
        ]
      : [
          const Color(0xFF1A1400), // dark gold
          const Color(0xFF2D2200), // warm gold
          const Color(0xFF1A1400), // dark gold
        ];

  Color get _borderColor =>
      _isMax ? HunterTheme.purple : HunterTheme.gold;

  Color get _glowColor =>
      _isMax ? HunterTheme.purple : HunterTheme.gold;

  double get _glowIntensity => _isMax ? 0.35 : 0.25;

  Color get _ringColor =>
      _isMax ? HunterTheme.purpleLight : HunterTheme.goldBright;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, staticChild) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Outer glow ──
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: widget.borderRadius,
                    boxShadow: [
                      BoxShadow(
                        color: _glowColor.withOpacity(
                            _glowIntensity * (0.7 + 0.3 * math.sin(_controller.value * math.pi * 2))),
                        blurRadius: _isMax ? 20 : 14,
                        spreadRadius: _isMax ? 3 : 2,
                      ),
                      if (_isMax)
                        BoxShadow(
                          color: HunterTheme.gold.withOpacity(
                              0.15 * (0.6 + 0.4 * math.cos(_controller.value * math.pi * 2))),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                ),
              ),

              // ── Rotating energy ring ──
              Positioned.fill(
                child: CustomPaint(
                  painter: _EnergyRingPainter(
                    progress: _controller.value,
                    color: _ringColor,
                    borderRadius: widget.borderRadius,
                    isMax: _isMax,
                  ),
                ),
              ),

              // ── Card with gradient background ──
              Container(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _gradientColors,
                  ),
                  border: Border.all(
                    color: _borderColor.withOpacity(0.7),
                    width: _isMax ? 1.8 : 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: widget.borderRadius,
                  child: Stack(
                    children: [
                      // ── Shimmer sweep (Max only) ──
                      if (_isMax)
                        Positioned.fill(
                          child: _ShimmerSweep(progress: _controller.value),
                        ),

                      // ── Sparkle particles ──
                      Positioned.fill(
                        child: _SparkleParticles(
                          progress: _controller.value,
                          isMax: _isMax,
                        ),
                      ),

                      // ── Actual card content ──
                      staticChild!,
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}


// ── Energy Ring Painter ──────────────────────────────────────────────────────

class _EnergyRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final BorderRadius borderRadius;
  final bool isMax;

  _EnergyRingPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.isMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(1);

    // Draw a partial arc that rotates around the card border.
    final arcLength = 0.25; // 25% of perimeter
    final startAngle = progress * math.pi * 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMax ? 2.5 : 2.0
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + arcLength * math.pi * 2,
        colors: [
          color.withOpacity(0),
          color.withOpacity(isMax ? 0.8 : 0.6),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);

    final path = Path()..addRRect(rrect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EnergyRingPainter old) =>
      old.progress != progress;
}

// ── Shimmer Sweep (Max only) ─────────────────────────────────────────────────

class _ShimmerSweep extends StatelessWidget {
  final double progress;
  const _ShimmerSweep({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Sweep every ~4 seconds (0.0 to 0.5 of the 9s cycle = ~4.5s)
    final sweepProgress = (progress * 2.0) % 1.0;
    if (progress > 0.5) return const SizedBox.shrink();

    return Opacity(
      opacity: 0.12,
      child: Transform.translate(
        offset: Offset(
          (sweepProgress - 0.5) * 400,
          0,
        ),
        child: Container(
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sparkle Particles ────────────────────────────────────────────────────────

class _SparkleParticles extends StatelessWidget {
  final double progress;
  final bool isMax;
  const _SparkleParticles({required this.progress, required this.isMax});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklePainter(
        progress: progress,
        color: isMax ? HunterTheme.purpleLight : HunterTheme.goldBright,
        particleCount: isMax ? 5 : 3,
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int particleCount;

  _SparklePainter({
    required this.progress,
    required this.color,
    required this.particleCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // Fixed seed for stable positions.
    final paint = Paint()..color = color;

    for (int i = 0; i < particleCount; i++) {
      final phase = (progress + i * 0.2) % 1.0;
      // Each particle is visible only briefly.
      final visibility = math.sin(phase * math.pi);
      if (visibility < 0.3) continue;

      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 1.0 + rng.nextDouble() * 1.5;

      paint.color = color.withOpacity(visibility * 0.6);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}



// ── Energy Ring Painter ──────────────────────────────────────────────────────

class _EnergyRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final BorderRadius borderRadius;
  final bool isMax;

  _EnergyRingPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
    required this.isMax,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(1);
    final startAngle = progress * math.pi * 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isMax ? 2.5 : 2.0
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          color.withOpacity(0),
          color.withOpacity(isMax ? 0.8 : 0.6),
          color.withOpacity(0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(rect);

    final path = Path()..addRRect(rrect);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EnergyRingPainter old) =>
      old.progress != progress;
}

// ── Shimmer Sweep (Max only) ─────────────────────────────────────────────────

class _ShimmerSweep extends StatelessWidget {
  final double progress;
  const _ShimmerSweep({required this.progress});

  @override
  Widget build(BuildContext context) {
    // Sweep visible during first half of the cycle (~4.5s).
    final sweepProgress = (progress * 2.0) % 1.0;
    if (progress > 0.5) return const SizedBox.shrink();

    return Opacity(
      opacity: 0.12,
      child: Align(
        alignment: Alignment(sweepProgress * 2 - 1, 0),
        child: Container(
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0),
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Sparkle Particles ────────────────────────────────────────────────────────

class _SparkleParticles extends StatelessWidget {
  final double progress;
  final bool isMax;
  const _SparkleParticles({required this.progress, required this.isMax});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SparklePainter(
        progress: progress,
        color: isMax ? HunterTheme.purpleLight : HunterTheme.goldBright,
        particleCount: isMax ? 5 : 3,
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final double progress;
  final Color color;
  final int particleCount;

  _SparklePainter({
    required this.progress,
    required this.color,
    required this.particleCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint();

    for (int i = 0; i < particleCount; i++) {
      final phase = (progress + i * 0.2) % 1.0;
      final visibility = math.sin(phase * math.pi);
      if (visibility < 0.3) continue;

      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final radius = 1.0 + rng.nextDouble() * 1.5;

      paint.color = color.withOpacity(visibility * 0.6);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}

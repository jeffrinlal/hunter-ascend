import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/sleep_service.dart';

/// Immersive full-screen animation shown briefly when a sleep session begins.
///
/// Displays a moon, animated stars, and a motivational message before
/// automatically popping back to the Dashboard after a few seconds.
class SleepStartScreen extends StatefulWidget {
  final SleepAmbience ambience;
  final AmbienceDuration duration;

  const SleepStartScreen({
    super.key,
    required this.ambience,
    required this.duration,
  });

  @override
  State<SleepStartScreen> createState() => _SleepStartScreenState();
}

class _SleepStartScreenState extends State<SleepStartScreen>
    with TickerProviderStateMixin {
  late final AnimationController _moonController;
  late final AnimationController _starsController;
  late final AnimationController _textController;
  late final Animation<double> _moonScale;
  late final Animation<double> _moonOpacity;
  late final Animation<double> _starsOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    // Moon: scales up and fades in over 800ms.
    _moonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _moonScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _moonController, curve: Curves.easeOutBack),
    );
    _moonOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _moonController, curve: Curves.easeOut),
    );

    // Stars: fade in after moon appears.
    _starsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _starsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _starsController, curve: Curves.easeIn),
    );

    // Text: fade + slide up.
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
    );

    // Sequence: moon → stars → text → auto-pop.
    _moonController.forward().then((_) {
      if (!mounted) return;
      _starsController.forward();
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        _textController.forward();
      });
    });

    // Auto-pop after the animation completes.
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  void dispose() {
    _moonController.dispose();
    _starsController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060A12),
      body: Stack(
        children: [
          // ── Stars background ──
          FadeTransition(
            opacity: _starsOpacity,
            child: const _StarField(),
          ),

          // ── Moon + text centered ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Moon
                AnimatedBuilder(
                  animation: _moonController,
                  builder: (context, child) => Opacity(
                    opacity: _moonOpacity.value,
                    child: Transform.scale(
                      scale: _moonScale.value,
                      child: child,
                    ),
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFFFF8E1),
                          const Color(0xFFFFE082),
                          const Color(0xFFFFCA28).withOpacity(0.6),
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFE082).withOpacity(0.4),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // Text
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textOpacity,
                    child: Column(
                      children: [
                        Text(
                          'Good night, Hunter.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tomorrow you\'ll awaken stronger.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              SleepService.ambienceIcon(widget.ambience),
                              color: Colors.white.withOpacity(0.4),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${SleepService.ambienceName(widget.ambience)} \u2022 ${SleepService.durationLabel(widget.duration)}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.35),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
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

/// Animated star field with slowly twinkling dots.
class _StarField extends StatefulWidget {
  const _StarField();

  @override
  State<_StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<_StarField> with SingleTickerProviderStateMixin {
  late final AnimationController _twinkle;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _twinkle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    final rng = math.Random(42);
    _stars = List.generate(50, (_) => _Star(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.0 + rng.nextDouble() * 2.0,
      phase: rng.nextDouble() * math.pi * 2,
    ));
  }

  @override
  void dispose() {
    _twinkle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _twinkle,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _StarPainter(stars: _stars, progress: _twinkle.value),
        );
      },
    );
  }
}

class _Star {
  const _Star({required this.x, required this.y, required this.size, required this.phase});
  final double x;
  final double y;
  final double size;
  final double phase;
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.stars, required this.progress});
  final List<_Star> stars;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final opacity = 0.3 + 0.7 * ((math.sin(progress * math.pi * 2 + star.phase) + 1) / 2);
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.progress != progress;
}

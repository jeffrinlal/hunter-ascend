import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/auth/quest_selection_screen.dart';

/// Animated "scanning" onboarding transition before quest selection.
class ScanningScreen extends StatefulWidget {
  const ScanningScreen({super.key});

  @override
  State<ScanningScreen> createState() => _ScanningScreenState();
}

class _ScanningScreenState extends State<ScanningScreen>
    with TickerProviderStateMixin {
  double progress = 0;

  Timer? _progressTimer;

  late AnimationController _scanLineController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _scanLineAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;

  final List<String> _statusMessages = [
    'Initializing hunter profile...',
    'Reading biometric data...',
    'Analyzing combat potential...',
    'Calculating rank threshold...',
    'Scanning Hunter Data...',
  ];
  String _currentStatus = 'Initializing hunter profile...';

  @override
  void initState() {
    super.initState();

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _scanLineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.linear),
    );

    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    // Progress timer — same logic as original
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      setState(() {
        progress += 0.025;

        // Cycle status messages based on progress
        final idx =
        ((progress / 1.0) * _statusMessages.length).toInt().clamp(
          0,
          _statusMessages.length - 1,
        );
        _currentStatus = _statusMessages[idx];
      });

      if (progress >= 1) {
        timer.cancel();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const QuestSelectionScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _scanLineController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: Stack(
        children: [
          // Grid background
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPainter(),
          ),

          // Ambient glow center
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, _) => Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      HunterTheme.primary
                          .withOpacity(0.07 * _pulseAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Moving scan line across the whole screen
          AnimatedBuilder(
            animation: _scanLineAnim,
            builder: (context, _) => Positioned(
              top: _scanLineAnim.value * size.height,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      HunterTheme.primary.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: HunterTheme.primary.withOpacity(0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Icon with scan box
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Outer ring
                              Container(
                                width: 130,
                                height: 130,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: HunterTheme.primary
                                        .withOpacity(0.15 * _pulseAnim.value),
                                    width: 1,
                                  ),
                                ),
                              ),
                              // Icon circle
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: HunterTheme.primary
                                      .withOpacity(0.07),
                                  border: Border.all(
                                    color: HunterTheme.primary
                                        .withOpacity(0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: HunterTheme.primary
                                          .withOpacity(
                                          0.3 * _pulseAnim.value),
                                      blurRadius: 30,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.memory,
                                  size: 48,
                                  color: HunterTheme.primary
                                      .withOpacity(
                                      0.7 + 0.3 * _pulseAnim.value),
                                ),
                              ),
                              // Corner bracket decorations
                              ..._buildCornerBrackets(110),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 36),

                      // Title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (context, _) => Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: HunterTheme.primary
                                    .withOpacity(_pulseAnim.value),
                                boxShadow: [
                                  BoxShadow(
                                    color: HunterTheme.primary
                                        .withOpacity(0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '[ SYSTEM ANALYSIS ]',
                            style: TextStyle(
                              color: HunterTheme.primary,
                              fontSize: 16,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          AnimatedBuilder(
                            animation: _pulseAnim,
                            builder: (context, _) => Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: HunterTheme.primary
                                    .withOpacity(_pulseAnim.value),
                                boxShadow: [
                                  BoxShadow(
                                    color: HunterTheme.primary
                                        .withOpacity(0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Progress bar container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: HunterTheme.cardColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Bar header row
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'SCAN PROGRESS',
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary.withOpacity(0.4),
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: HunterTheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            // Custom segmented progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor:
                                HunterTheme.textPrimary.withOpacity(0.07),
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  HunterTheme.primary,
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Status message
                            Row(
                              children: [
                                Icon(
                                  Icons.chevron_right,
                                  color: HunterTheme.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _currentStatus,
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary.withOpacity(0.6),
                                    fontSize: 12,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Corner bracket decorations around the icon
  List<Widget> _buildCornerBrackets(double boxSize) {
    final color = HunterTheme.primary;
    const len = 14.0;
    const thick = 1.5;
    final half = boxSize / 2;

    Widget bracket(double top, double left, double? right, double? bottom,
        bool flipH, bool flipV) {
      return Positioned(
        top: top,
        left: left >= 0 ? left : null,
        right: right,
        child: SizedBox(
          width: len + thick,
          height: len + thick,
          child: CustomPaint(
            painter: _BracketPainter(
                color: color, flipH: flipH, flipV: flipV),
          ),
        ),
      );
    }

    return [
      bracket(-half, -half, null, null, false, false),
      bracket(-half, 0, -half.toDouble(), null, true, false),
      bracket(0, -half, null, -half.toDouble(), false, true),
      bracket(0, 0, -half.toDouble(), -half.toDouble(), true, true),
    ];
  }
}

// ── Corner bracket painter ───────────────────────────────────────────────────

class _BracketPainter extends CustomPainter {
  final Color color;
  final bool flipH;
  final bool flipV;

  _BracketPainter({required this.color, required this.flipH, required this.flipV});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    if (!flipH && !flipV) {
      path.moveTo(size.width, 0);
      path.lineTo(0, 0);
      path.lineTo(0, size.height);
    } else if (flipH && !flipV) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!flipH && flipV) {
      path.moveTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Grid background ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HunterTheme.primary.withOpacity(0.03)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'awakening_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:math' as math;

import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _navigate(BuildContext context, Map<String, dynamic>? data, bool onboardingDone) {
    if (!context.mounted) return;
    if (onboardingDone) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardScreen(
            fatLoss: data?['fatLoss'] ?? false,
            discipline: data?['discipline'] ?? false,
            muscleGain: data?['muscleGain'] ?? false,
            selfImprovement: data?['selfImprovement'] ?? false,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AwakeningScreen()),
      );
    }
  }

  Future<void> signInGuest(BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        user = credential.user;
      }

      if (user == null) return;

      final docRef =
      FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      final doc = await docRef.get();
      final data = doc.data();
      final bool onboardingDone =
          doc.exists && (data?['onboardingComplete'] ?? false) == true;

      if (!doc.exists) {
        await docRef.set({
          'hunterName': 'Hunter_${user.uid.substring(0, 6)}',
          'level': 1,
          'xp': 0,
          'streak': 0,
          'lastQuestDate': '',
          'onboardingComplete': false,
        });
      }

      _navigate(context, data, onboardingDone);
    } catch (e) {
      print("❌ Guest Sign In error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign in failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> signInWithGoogle(BuildContext context) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) return;

      final docRef =
      FirebaseFirestore.instance.collection('hunters').doc(user.uid);
      final doc = await docRef.get();
      final data = doc.data();
      final bool onboardingDone =
          doc.exists && (data?['onboardingComplete'] ?? false) == true;

      if (!doc.exists) {
        await docRef.set({
          'hunterName': 'Hunter_${user.uid.substring(0, 6)}',
          'level': 1,
          'xp': 0,
          'streak': 0,
          'lastQuestDate': '',
          'onboardingComplete': false,
        });
      }

      _navigate(context, data, onboardingDone);
    } catch (e) {
      print("❌ Google Sign In error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sign in failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Stack(
        children: [
          CustomPaint(
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
            painter: _GridPainter(),
          ),

          AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, _) {
              return Positioned(
                top: -80,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF00E5FF)
                              .withOpacity(0.12 * _glowAnimation.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),

                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, _) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0D1620),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withOpacity(0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00E5FF).withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: _ShieldCrestIcon(),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'HUNTER ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                          TextSpan(
                            text: 'ASCEND',
                            style: TextStyle(
                              color: Color(0xFF00E5FF),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'YOUR AWAKENING BEGINS',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.35),
                        fontSize: 11,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      width: 60,
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF00E5FF),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00E5FF).withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Loading indicator
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                          strokeWidth: 2,
                        ),
                      ),

                    _HunterButton(
                      onTap: _isLoading ? () {} : () => signInWithGoogle(context),
                      label: 'CONTINUE WITH GOOGLE',
                      icon: _GoogleIcon(),
                      isPrimary: false,
                      isDisabled: _isLoading,
                    ),

                    const SizedBox(height: 16),

                    _HunterButton(
                      onTap: _isLoading ? () {} : () => signInGuest(context),
                      label: 'ENTER AS GUEST',
                      icon: const Icon(
                        Icons.bolt,
                        color: Color(0xFF080C14),
                        size: 18,
                      ),
                      isPrimary: true,
                      isDisabled: _isLoading,
                    ),

                    const Spacer(flex: 1),

                    Text(
                      'By continuing you accept our Terms & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable button ──────────────────────────────────────────────────────────

class _HunterButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final Widget icon;
  final bool isPrimary;
  final bool isDisabled;

  const _HunterButton({
    required this.onTap,
    required this.label,
    required this.icon,
    required this.isPrimary,
    this.isDisabled = false,
  });

  @override
  State<_HunterButton> createState() => _HunterButtonState();
}

class _HunterButtonState extends State<_HunterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.isDisabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.isDisabled ? null : (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: widget.isDisabled ? 0.5 : 1.0,
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? const Color(0xFF00E5FF)
                  : const Color(0xFF0D1620),
              borderRadius: BorderRadius.circular(6),
              border: widget.isPrimary
                  ? null
                  : Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.4),
                width: 1,
              ),
              boxShadow: widget.isPrimary
                  ? [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 1,
                ),
              ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                widget.icon,
                const SizedBox(width: 10),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isPrimary
                        ? const Color(0xFF080C14)
                        : Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shield crest icon ────────────────────────────────────────────────────────

class _ShieldCrestIcon extends StatelessWidget {
  const _ShieldCrestIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(52, 58),
      painter: _ShieldPainter(),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cyanColor = const Color(0xFF00E5FF);
    final paint = Paint()
      ..color = cyanColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = cyanColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height * 0.25);
    path.lineTo(size.width, size.height * 0.6);
    path.quadraticBezierTo(
        size.width, size.height, size.width / 2, size.height);
    path.quadraticBezierTo(0, size.height, 0, size.height * 0.6);
    path.lineTo(0, size.height * 0.25);
    path.close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, strokePaint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          color: cyanColor,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Google icon ──────────────────────────────────────────────────────────────

class _GoogleIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.1),
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 1,
        ),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Background grid ──────────────────────────────────────────────────────────

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.03)
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
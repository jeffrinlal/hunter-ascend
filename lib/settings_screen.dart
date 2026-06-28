import 'package:flutter/material.dart';
import 'Theme/hunter_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      if (user.isAnonymous) {
        // Delete Firestore data first
        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .delete();

        // Then delete the anonymous Firebase Auth account
        await user.delete();
        // user.delete() also signs out automatically
      } else {
        // Google user — sign out from Google + Firebase
        await GoogleSignIn().signOut();
        await FirebaseAuth.instance.signOut();
      }

      // Navigate to login and clear all routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Logout error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HunterTheme.cardColor,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.redAccent, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            content: Text(
              '[ ERROR ] Logout failed: $e',
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }
    }
  }

  void _showLogoutConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: HunterTheme.primary.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.logout,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 16),
              const Text(
                'LOGOUT',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Guest accounts will be permanently deleted. Are you sure?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: HunterTheme.textPrimary.withOpacity(0.5),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: HunterTheme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'CANCEL',
                            style: TextStyle(
                              color: HunterTheme.textPrimary.withOpacity(0.5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleLogout(context);
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.6),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'LOGOUT',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: Stack(
        children: [
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPainter(),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: HunterTheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: HunterTheme.primary
                                      .withOpacity(0.8),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '[ SYSTEM ]',
                            style: TextStyle(
                              color: HunterTheme.primary.withOpacity(0.7),
                              fontSize: 11,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 60,
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              HunterTheme.primary,
                              Colors.transparent,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: HunterTheme.primary.withOpacity(0.4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Settings items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _sectionLabel('GENERAL'),
                      const SizedBox(height: 10),

                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        title: 'Privacy Policy',
                        subtitle: 'View our data & privacy terms',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrivacyPolicyScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 10),

                      _SettingsTile(
                        icon: Icons.info_outline,
                        title: 'About Hunter Ascend',
                        subtitle: 'Version 1.0.0',
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              backgroundColor: HunterTheme.cardColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: HunterTheme.primary
                                      .withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.bolt,
                                      color: HunterTheme.primary,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'HUNTER ASCEND',
                                      style: TextStyle(
                                        color: HunterTheme.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Version 1.0.0',
                                      style: TextStyle(
                                        color: HunterTheme.primary
                                            .withOpacity(0.7),
                                        fontSize: 12,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Level Up Your Real Life.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: HunterTheme.textPrimary.withOpacity(0.5),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    GestureDetector(
                                      onTap: () => Navigator.pop(ctx),
                                      child: Container(
                                        width: double.infinity,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: HunterTheme.primary,
                                          borderRadius:
                                          BorderRadius.circular(6),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'CLOSE',
                                            style: TextStyle(
                                              color: HunterTheme.background,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 2,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      _sectionLabel('ACCOUNT'),
                      const SizedBox(height: 10),

                      _SettingsTile(
                        icon: Icons.logout,
                        title: 'Logout',
                        subtitle: 'Sign out of your hunter account',
                        isDanger: true,
                        onTap: () => _showLogoutConfirm(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: HunterTheme.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: HunterTheme.textPrimary.withOpacity(0.35),
            fontSize: 10,
            letterSpacing: 2.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ── Settings tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent =
    widget.isDanger ? Colors.redAccent : HunterTheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: accent.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: accent.withOpacity(0.25),
                    width: 1,
                  ),
                ),
                child: Icon(widget.icon, color: accent, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isDanger
                            ? Colors.redAccent
                            : HunterTheme.textPrimary.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: HunterTheme.textPrimary.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: accent.withOpacity(0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Privacy Policy Screen ─────────────────────────────────────────────────────

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: HunterTheme.cardColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: HunterTheme.primary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: HunterTheme.primary,
                        size: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'PRIVACY POLICY',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: HunterTheme.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: HunterTheme.primary.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '''Privacy Policy for Hunter Ascend: Fitness Duels

Last Updated: June 2026

Hunter Ascend: Fitness Duels ("the App") is committed to protecting your privacy. This Privacy Policy explains how information is collected, used, and protected when you use the App.

INFORMATION WE COLLECT

The App may collect and store the following information:

• User authentication information provided through Firebase Authentication.
• Anonymous user identifiers generated by Firebase.
• Profile information such as Hunter Name and Profile Picture (if provided).
• Fitness challenge and duel-related information.
• Progress data including XP, levels, wins, losses, streaks, and achievements.
• Technical information necessary for app functionality and security.

HOW WE USE INFORMATION

We use collected information to:

• Create and manage user accounts.
• Enable fitness duels and challenges.
• Track progress and achievements.
• Improve app functionality and performance.
• Prevent abuse, cheating, and unauthorized access.

FIREBASE SERVICES

Hunter Ascend uses Google Firebase services, including Firebase Authentication, Cloud Firestore, and Firebase Storage. These services may collect information as described in Google's Privacy Policy.

DATA SECURITY

Reasonable measures are taken to protect user information from unauthorized access, alteration, or disclosure. However, no internet-based service can guarantee complete security.

CHILDREN'S PRIVACY

The App is not directed toward children under the age of 13. We do not knowingly collect personal information from children under 13.

CONTACT

For questions regarding this Privacy Policy, contact:
djdeveloper1202@gmail.com''',
                    style: TextStyle(
                      color: HunterTheme.textPrimary.withOpacity(0.65),
                      fontSize: 13,
                      height: 1.8,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Grid background ───────────────────────────────────────────────────────────

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
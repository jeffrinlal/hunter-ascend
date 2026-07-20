import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hunter_ascend/screens/auth/login_screen.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/screens/settings/theme_gallery_screen.dart';
import 'package:hunter_ascend/data/repositories/hunter_repository.dart';
import 'package:hunter_ascend/data/repositories/weight_repository.dart';
import 'package:hunter_ascend/data/repositories/quest_repository.dart';
import 'package:hunter_ascend/data/repositories/leaderboard_repository.dart';
import 'package:hunter_ascend/services/sleep_service.dart';
import 'package:hunter_ascend/services/rank_reward_service.dart';
import 'package:hunter_ascend/services/equipped_rewards_service.dart';
import 'package:hunter_ascend/services/achievements_service.dart';

/// App settings: theme toggle, account, and links.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      // Clear cached membership so the next signed-in user starts fresh.
      MembershipService.instance.clearCache();
      await HunterRepository.instance.clearCache();
      await WeightRepository.instance.clearCache();
      await QuestRepository.instance.clearCache();
      await LeaderboardRepository.instance.clearCache();
      await SleepService.instance.cancelSleep();
      RankRewardService.instance.clearCache();
      EquippedRewardsService.instance.clearCache();
      AchievementsService.instance.clearCache();

      if (user.isAnonymous) {
        // Delete Firestore data first (while auth token is still valid),
        // then delete the anonymous Firebase Auth account.
        await FirebaseFirestore.instance
            .collection('hunters')
            .doc(user.uid)
            .delete();

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
              Text(
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

  void _showDeleteAccountConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: Colors.redAccent.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 16),
              Text(
                'DELETE ACCOUNT',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This will permanently delete your account, all progress, XP, streaks, and hunter data. This action cannot be undone.',
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
                        _handleDeleteAccount(context);
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Center(
                          child: Text(
                            'DELETE',
                            style: TextStyle(
                              color: Colors.white,
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

  Future<void> _handleDeleteAccount(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      MembershipService.instance.clearCache();
      await HunterRepository.instance.clearCache();
      await WeightRepository.instance.clearCache();
      await QuestRepository.instance.clearCache();
      await LeaderboardRepository.instance.clearCache();
      await SleepService.instance.cancelSleep();
      RankRewardService.instance.clearCache();
      EquippedRewardsService.instance.clearCache();
      AchievementsService.instance.clearCache();

      // Re-authenticate with Google before deletion (required by Firebase
      // for destructive operations if the sign-in is not recent).
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: HunterTheme.cardColor,
              content: Text(
                'Re-authentication required to delete account.',
                style: TextStyle(color: HunterTheme.textPrimary, fontSize: 12),
              ),
            ),
          );
        }
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await user.reauthenticateWithCredential(credential);

      // Delete Firestore user data
      await FirebaseFirestore.instance
          .collection('hunters')
          .doc(user.uid)
          .delete();

      // Delete the hunterName reservation (if it exists)
      final hunterDoc = await FirebaseFirestore.instance
          .collection('hunterNames')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      for (final doc in hunterDoc.docs) {
        await doc.reference.delete();
      }

      // Delete the Firebase Auth account
      await user.delete();

      await googleSignIn.signOut();

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Delete account error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HunterTheme.cardColor,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.redAccent, width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            content: Text(
              'Account deletion failed. Please try again.',
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return Scaffold(
      backgroundColor: HunterTheme.background,
      body: Stack(
        children: [
          // Subtle premium backdrop wash (top-anchored primary glow).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    HunterTheme.primary.withOpacity(0.10),
                    HunterTheme.background,
                  ],
                  stops: const [0.0, 0.42],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Premium header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HunterTheme.cardColor,
                            border: Border.all(color: HunterTheme.border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Icon(Icons.arrow_back_ios_new_rounded, color: HunterTheme.textSecondary, size: 15),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [HunterTheme.primary, HunterTheme.primary.withOpacity(0.7)],
                          ),
                          boxShadow: [
                            BoxShadow(color: HunterTheme.primary.withOpacity(0.35), blurRadius: 14),
                          ],
                        ),
                        child: const Icon(Icons.settings_rounded, color: Colors.black, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'SETTINGS',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HunterTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Customize your hunter experience',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: HunterTheme.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Settings items
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    children: [
                      _sectionLabel('APPEARANCE'),
                      const SizedBox(height: 10),

                      const _DarkModeTile(),

                      const SizedBox(height: 10),

                      _SettingsTile(
                        icon: Icons.palette_outlined,
                        title: 'Premium Themes',
                        subtitle: 'Customize your hunter experience',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ThemeGalleryScreen(),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 24),
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
                                    Icon(
                                      Icons.bolt,
                                      color: HunterTheme.primary,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
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
                                        child: Center(
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

                      // Account deletion for Google users
                      if (FirebaseAuth.instance.currentUser != null &&
                          !FirebaseAuth.instance.currentUser!.isAnonymous) ...[
                        const SizedBox(height: 10),
                        _SettingsTile(
                          icon: Icons.delete_forever,
                          title: 'Delete Account',
                          subtitle: 'Permanently delete your account and all data',
                          isDanger: true,
                          onTap: () => _showDeleteAccountConfirm(context),
                        ),
                      ],
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
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [HunterTheme.primary, HunterTheme.primary.withOpacity(0.5)],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
    final accent = widget.isDanger ? HunterTheme.danger : HunterTheme.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: HunterTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDanger ? accent.withOpacity(0.28) : HunterTheme.border,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withOpacity(0.25)),
                ),
                child: Icon(widget.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isDanger ? accent : HunterTheme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: HunterTheme.textSecondary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dark Mode toggle tile ─────────────────────────────────────────────────────

class _DarkModeTile extends StatelessWidget {
  const _DarkModeTile();

  Future<void> _setDark(bool value) async {
    HunterTheme.isDark = value;
    themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', value);
  }

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.primary;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return GestureDetector(
          onTap: () => _setDark(!isDark),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: HunterTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: HunterTheme.border),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withOpacity(0.18), accent.withOpacity(0.06)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.25)),
                  ),
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dark Mode',
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isDark
                            ? 'Dark theme enabled'
                            : 'Light theme (white + orange)',
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _PremiumToggle(value: isDark, onChanged: _setDark),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A modern, premium animated toggle switch. Purely presentational — the
/// callback wiring is identical to the previous [Switch].
class _PremiumToggle extends StatelessWidget {
  const _PremiumToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = HunterTheme.primary;
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          gradient: value
              ? LinearGradient(colors: [accent, accent.withOpacity(0.75)])
              : null,
          color: value ? null : HunterTheme.textTertiary.withOpacity(0.30),
          borderRadius: BorderRadius.circular(20),
          boxShadow: value
              ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 10)]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Privacy Policy Screen ─────────────────────────────────────────────────────

/// Static privacy-policy page linked from settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
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
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HunterTheme.cardColor,
                        border: Border.all(color: HunterTheme.border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: HunterTheme.textSecondary,
                        size: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
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
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: HunterTheme.border),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
                    ],
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


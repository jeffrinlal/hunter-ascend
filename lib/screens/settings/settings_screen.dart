import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hunter_ascend/services/account_deletion_service.dart';
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
import 'package:hunter_ascend/services/daily_reward_service.dart';
import 'package:hunter_ascend/services/milestone_service.dart';
import 'package:hunter_ascend/services/rank_celebration_service.dart';

/// App settings: theme toggle, account, and links.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) return;

      debugPrint('[Logout] START — uid=${user.uid}, isAnonymous=${user.isAnonymous}');

      debugPrint('[Logout] 1/9 AchievementsService.clearCache() — before');
      AchievementsService.instance.clearCache();
      debugPrint('[Logout] 1/9 AchievementsService.clearCache() — after');

      debugPrint('[Logout] 2/9 RankRewardService.clearCache() — before');
      RankRewardService.instance.clearCache();
      debugPrint('[Logout] 2/9 RankRewardService.clearCache() — after');

      debugPrint('[Logout] 3/9 EquippedRewardsService.clearCache() — before');
      EquippedRewardsService.instance.clearCache();
      debugPrint('[Logout] 3/9 EquippedRewardsService.clearCache() — after');

      debugPrint('[Logout] 4/9 MembershipService.clearCache() — before');
      MembershipService.instance.clearCache();
      debugPrint('[Logout] 4/9 MembershipService.clearCache() — after');

      debugPrint('[Logout] 5a/9 HunterRepository.clearCache() — before');
      try {
        await HunterRepository.instance.clearCache();
        debugPrint('[Logout] 5a/9 HunterRepository.clearCache() — SUCCESS');
      } catch (e, st) {
        debugPrint('[Logout] 5a/9 FAILED — HunterRepository.instance.clearCache()');
        debugPrint('[Logout] 5a/9 exception: $e');
        debugPrint('[Logout] 5a/9 stack: $st');
        rethrow;
      }

      debugPrint('[Logout] 5b/9 WeightRepository.clearCache() — before');
      try {
        await WeightRepository.instance.clearCache();
        debugPrint('[Logout] 5b/9 WeightRepository.clearCache() — SUCCESS');
      } catch (e, st) {
        debugPrint('[Logout] 5b/9 FAILED — WeightRepository.instance.clearCache()');
        debugPrint('[Logout] 5b/9 exception: $e');
        debugPrint('[Logout] 5b/9 stack: $st');
        rethrow;
      }

      debugPrint('[Logout] 5c/9 QuestRepository.clearCache() — before');
      try {
        await QuestRepository.instance.clearCache();
        debugPrint('[Logout] 5c/9 QuestRepository.clearCache() — SUCCESS');
      } catch (e, st) {
        debugPrint('[Logout] 5c/9 FAILED — QuestRepository.instance.clearCache()');
        debugPrint('[Logout] 5c/9 exception: $e');
        debugPrint('[Logout] 5c/9 stack: $st');
        rethrow;
      }

      debugPrint('[Logout] 5d/9 LeaderboardRepository.clearCache() — before');
      try {
        await LeaderboardRepository.instance.clearCache();
        debugPrint('[Logout] 5d/9 LeaderboardRepository.clearCache() — SUCCESS');
      } catch (e, st) {
        debugPrint('[Logout] 5d/9 FAILED — LeaderboardRepository.instance.clearCache()');
        debugPrint('[Logout] 5d/9 exception: $e');
        debugPrint('[Logout] 5d/9 stack: $st');
        rethrow;
      }

      debugPrint('[Logout] 6/9 SleepService.cancelSleep() — before');
      try {
        await SleepService.instance.cancelSleep();
        debugPrint('[Logout] 6/9 SleepService.cancelSleep() — SUCCESS');
      } catch (e, st) {
        debugPrint('[Logout] 6/9 FAILED — SleepService.instance.cancelSleep()');
        debugPrint('[Logout] 6/9 exception: $e');
        debugPrint('[Logout] 6/9 stack: $st');
        rethrow;
      }

      if (user.isAnonymous) {
        debugPrint('[Logout] 7/9 Anonymous path — deleting hunters/${user.uid}');
        debugPrint('[Logout] 7/9 currentUser before delete: ${FirebaseAuth.instance.currentUser?.uid}');
        try {
          await FirebaseFirestore.instance
              .collection('hunters')
              .doc(user.uid)
              .delete();
          debugPrint('[Logout] 7/9 hunters/${user.uid} .delete() — SUCCESS');
        } catch (e, st) {
          debugPrint('[Logout] 7/9 FAILED — FirebaseFirestore.collection("hunters").doc("${user.uid}").delete()');
          debugPrint('[Logout] 7/9 exception: $e');
          debugPrint('[Logout] 7/9 stack: $st');
          rethrow;
        }

        debugPrint('[Logout] 8/9 user.delete() — before');
        try {
          await user.delete();
          debugPrint('[Logout] 8/9 user.delete() — SUCCESS');
        } catch (e, st) {
          debugPrint('[Logout] 8/9 FAILED — FirebaseAuth user.delete() uid=${user.uid}');
          debugPrint('[Logout] 8/9 exception: $e');
          debugPrint('[Logout] 8/9 stack: $st');
          rethrow;
        }
      } else {
        debugPrint('[Logout] 7/9 Google path — signing out');
        debugPrint('[Logout] 7/9 currentUser before signOut: ${FirebaseAuth.instance.currentUser?.uid}');
        try {
          await GoogleSignIn().signOut();
          debugPrint('[Logout] 7/9 GoogleSignIn().signOut() — SUCCESS');
        } catch (e, st) {
          debugPrint('[Logout] 7/9 FAILED — GoogleSignIn().signOut()');
          debugPrint('[Logout] 7/9 exception: $e');
          debugPrint('[Logout] 7/9 stack: $st');
          rethrow;
        }

        debugPrint('[Logout] 8/9 FirebaseAuth.signOut() — before');
        debugPrint('[Logout] 8/9 currentUser before FirebaseAuth.signOut: ${FirebaseAuth.instance.currentUser?.uid}');
        try {
          await FirebaseAuth.instance.signOut();
          debugPrint('[Logout] 8/9 FirebaseAuth.signOut() — SUCCESS');
        } catch (e, st) {
          debugPrint('[Logout] 8/9 FAILED — FirebaseAuth.instance.signOut()');
          debugPrint('[Logout] 8/9 exception: $e');
          debugPrint('[Logout] 8/9 stack: $st');
          rethrow;
        }
      }

      debugPrint('[Logout] 9/9 Navigate to LoginScreen');

      // Navigate to login and clear all routes
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }

      debugPrint('[Logout] COMPLETE — no errors');
    } catch (e, stackTrace) {
      debugPrint('[Logout] EXCEPTION: $e');
      debugPrint('[Logout] STACK TRACE:\n$stackTrace');
      debugPrint('[Logout] currentUser at exception time: ${FirebaseAuth.instance.currentUser?.uid}');
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
                'This permanently deletes your account and known private data. Finish or cancel active duels first; completed shared duel history remains for other participants. Awarded achievement claims are left behind only to preserve recovery if Auth deletion fails while this UID remains active; after successful Auth deletion, they are inaccessible.',
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

  Future<void> _runLocalAccountCleanup(
    String label,
    Future<void> Function() cleanup,
  ) async {
    try {
      await cleanup();
    } catch (e, stackTrace) {
      // Firebase deletion has already succeeded at this point. Keep clearing
      // the remaining account-scoped state and do not report success as a
      // retryable failure merely because a local cache is unavailable.
      debugPrint('Delete account local cleanup ($label): $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _clearDeletedAccountLocalState(String uid) async {
    // Stop account-scoped listeners first, then clear every account cache and
    // preference. Each task is isolated so one device-local failure cannot
    // leave later stores untouched or block the completed deletion flow.
    await _runLocalAccountCleanup(
      'achievements',
      () async => AchievementsService.instance.clearCache(),
    );
    await _runLocalAccountCleanup(
      'rank rewards',
      () async => RankRewardService.instance.clearCache(),
    );
    await _runLocalAccountCleanup(
      'equipped rewards',
      () async => EquippedRewardsService.instance.clearCache(),
    );
    await _runLocalAccountCleanup(
      'membership',
      MembershipService.instance.clearAccountData,
    );
    await _runLocalAccountCleanup(
      'hunter cache',
      HunterRepository.instance.clearCache,
    );
    await _runLocalAccountCleanup(
      'weight cache',
      WeightRepository.instance.clearCache,
    );
    await _runLocalAccountCleanup(
      'quest cache',
      QuestRepository.instance.clearCache,
    );
    await _runLocalAccountCleanup(
      'leaderboard cache',
      LeaderboardRepository.instance.clearCache,
    );
    await _runLocalAccountCleanup(
      'sleep',
      SleepService.instance.clearAccountData,
    );
    await _runLocalAccountCleanup(
      'daily reward',
      DailyRewardService.instance.clearAccountData,
    );
    await _runLocalAccountCleanup(
      'milestones',
      MilestoneService.clearAccountData,
    );
    await _runLocalAccountCleanup(
      'rank celebrations',
      () => RankCelebrationService.instance.clearAccountData(uid),
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    var firestoreCleanupCompleted = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;

      // Firebase requires a recent Google credential before deleting the Auth
      // identity. Re-authenticate before any Firestore data is changed.
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

      // Client-only cleanup can delete only explicitly known, user-owned
      // paths. The service verifies the authenticated UID and blocks deletion
      // while a shared duel is active.
      final cleanup = await AccountDeletionService.instance
          .deleteCurrentUserData(user.uid);
      firestoreCleanupCompleted = true;
      debugPrint(
        'Account deletion kept '
        '${cleanup.retainedAwardedAchievements} awarded achievement claim(s) '
        'for same-UID deletion recovery.',
      );

      // Delete Auth last. If this fails, the signed-in user can reauthenticate
      // and retry; the Firestore cleanup is intentionally idempotent.
      await user.delete();

      await _clearDeletedAccountLocalState(user.uid);

      // Auth deletion has completed. Provider/SDK sign-outs are best-effort
      // local cleanup and must not change the successful result.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Delete account Firebase sign-out: $e');
      }
      try {
        await googleSignIn.signOut();
      } catch (e) {
        debugPrint('Delete account Google sign-out: $e');
      }

      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } on AccountDeletionException catch (e, stackTrace) {
      debugPrint('Delete account blocked: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showDeleteAccountError(context, e.message);
      }
    } catch (e, stackTrace) {
      debugPrint('Delete account error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (context.mounted) {
        _showDeleteAccountError(
          context,
          firestoreCleanupCompleted
              ? 'Your deletable Firestore data was removed, but your sign-in '
                  'account could not be deleted. Re-authenticate and retry '
                  'deletion.'
              : 'Account deletion could not finish. Some data may already '
                  'have been removed; stay signed in and retry.',
        );
      }
    }
  }

  void _showDeleteAccountError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.redAccent, width: 1),
          borderRadius: BorderRadius.circular(6),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
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
                          subtitle: 'Permanently delete your account and private data',
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

Last Updated: July 2026

Hunter Ascend: Fitness Duels ("the App") is committed to protecting your privacy. This Privacy Policy explains how information is collected, used, and protected when you use the App.

INFORMATION WE COLLECT

Account Data
When you create a hunter profile, we collect your hunter name, age, height, weight, and fitness goals. If you sign in with Google, we receive your email address and display name via Google Sign-In. Guest (anonymous) accounts use only a Firebase-generated identifier.

Usage & Progress Data
We collect data about how you use the App, including completed quests, streaks, XP, levels, duel participation and results, and leaderboard activity.

Step & Activity Data
With your permission (Activity Recognition), we read step-count data from your device's pedometer to track your daily steps within the App.

Location Data
With your permission, we access your device's GPS location for the run-tracking feature (Map screen). Location is used to display your route and calculate distance. Only the route points and summary of runs you choose to save are stored in your account document; we do not otherwise store a history of your location.

Camera & Photo Library
With your permission, we access your device's camera and photo library so you can upload a profile picture and photograph food for AI-assisted calorie estimation. Profile pictures are compressed and stored as image data inside your account document. Food photos are sent to our AI proxy for a one-time estimate and are not stored permanently by us.

Nutrition & AI-Generated Content
Food descriptions/photos and fitness profile details (level, streak, weight, height, goals) may be sent to a server-side AI proxy we operate to generate personalized quests and estimate meal nutrition. That proxy forwards requests to third-party AI providers (Google Gemini, Mistral AI, and Groq) on our behalf; our API keys for these providers are never exposed to your device.

HOW WE USE YOUR INFORMATION

• To provide and maintain the Hunter Ascend service.
• To generate personalized quests and estimate nutrition from the data described above.
• To display your profile, rank, and stats on leaderboards, duels, and hunter comparisons.
• To track your progress and award XP, levels, streaks, and achievements.
• To send local mission-reminder notifications, if enabled.
• To show advertisements to Basic-tier users, and to grant Pro/Max membership time after you watch a rewarded ad.

THIRD-PARTY SERVICES

We use the following third-party services:

• Firebase Authentication — Google LLC (anonymous and Google Sign-In)
• Cloud Firestore — Google LLC (data storage)
• Google Mobile Ads (AdMob) — Google LLC (banner and rewarded advertising)
• Google Gemini, Mistral AI, and Groq — quest generation and calorie estimation, accessed only through our own server-side proxy
• Facebook App Events — Meta Platforms, Inc. (app-activation event tracking)
• Workmanager — local background task scheduling for reminder notifications (runs entirely on your device)

These services may collect information according to their own privacy policies.

NOTIFICATIONS

Hunter Ascend may send local notifications to remind you to complete your daily missions or protect your streak. These are scheduled entirely on your device; we do not send push notifications from a remote server. You can adjust or disable reminders within the App.

MEMBERSHIP & ADVERTISING

Hunter Ascend does not use Google Play subscriptions or in-app purchases. Pro and Max membership time is earned by watching rewarded video ads served by Google AdMob. Basic-tier users may also see banner ads. Membership benefits expire once your accumulated time runs out and must be renewed by watching additional rewarded ads.

DATA STORAGE

Your data is stored in Google Cloud Firestore. We do not sell your personal data to third parties.

DATA SECURITY

Reasonable measures are taken to protect user information from unauthorized access, alteration, or disclosure. However, no internet-based service can guarantee complete security.

DATA RETENTION & ACCOUNT DELETION

Your account data is retained while your account is active. Guest (anonymous) accounts can be deleted at any time from Settings. Google-linked accounts can be permanently deleted from Settings, which removes your known private data (custom quests, weight history, runs, meal logs, and your hunter profile). Two categories of data are intentionally not removed: shared duel history, which is preserved for the other participant, and achievement claims that had already paid out XP, which are left behind only as an inaccessible safeguard against duplicate rewards if deletion fails partway through. Deletion is blocked while you have an active duel.

CHILDREN'S PRIVACY

The App is not directed toward children under the age of 13. We do not knowingly collect personal information from children under 13.

YOUR RIGHTS

You may request deletion of your account and associated data at any time using the account deletion feature in Settings, or by contacting us at the email below.

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


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/screens/dashboard/home_dashboard_screen.dart';
import 'package:hunter_ascend/screens/dashboard/missions_screen.dart';
import 'package:hunter_ascend/screens/leaderboard/global_rankings_screen.dart';
import 'package:hunter_ascend/screens/profile/profile_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_request_screen.dart';
import 'package:hunter_ascend/screens/duel/create_duel_screen.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/screens/profile/membership_screen.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/core/navigation_controller.dart';
import 'package:hunter_ascend/widgets/hunter_bottom_nav.dart';
import 'dart:async';

/// Persistent shell hosting the main app screens behind a bottom NavigationBar.
/// Tabs: Home (Dashboard), Quests, Leaderboard, Duels, Profile.
/// Login + onboarding (Awakening/Assessment) are NOT wrapped by this shell.
/// Persistent bottom-nav shell hosting the five main tabs.
class MainShell extends StatefulWidget {
  final bool fatLoss;
  final bool discipline;
  final bool muscleGain;
  final bool selfImprovement;
  final List<Map<String, dynamic>> bioQuests;

  const MainShell({
    super.key,
    this.fatLoss = false,
    this.discipline = false,
    this.muscleGain = false,
    this.selfImprovement = false,
    this.bioQuests = const [],
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  bool _isOpeningDuels = false;
  bool _hasDuelBadge = false;
  StreamSubscription<QuerySnapshot>? _badgeSub;

  // ── Page transition animation ──────────────────────────────────────────
  // Animates the incoming tab with a quick fade + slide. IndexedStack
  // switches the visible child immediately (it cannot show two children
  // at once), so a true crossfade is impossible without abandoning state
  // preservation. Instead, we animate the entrance of the new page with
  // a very subtle reveal (opacity 0→1, 2% slide) that feels responsive.
  late final AnimationController _transitionController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _fadeAnimation = Tween<double>(
    begin: 0.6,
    end: 1.0,
  ).animate(CurvedAnimation(
    parent: _transitionController,
    curve: Curves.easeOut,
  ));
  late final Animation<Offset> _slideAnimation = Tween<Offset>(
    begin: const Offset(0.015, 0),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _transitionController,
    curve: Curves.easeOutCubic,
  ));

  @override
  void initState() {
    super.initState();
    _transitionController.value = 1.0; // Start fully visible (no animation on first render).

    // Listen to tabNotifier for tab changes from pushed routes.
    tabNotifier.addListener(_onTabNotifierChanged);

    // Listen to duel-request badge stream.
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _badgeSub = FirebaseFirestore.instance
          .collection('duel_requests')
          .where('toUid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .snapshots()
          .listen((snap) {
        if (!mounted) return;
        final hasPending = snap.docs.isNotEmpty;
        if (hasPending != _hasDuelBadge) {
          setState(() => _hasDuelBadge = hasPending);
        }
      });
    }

    // Check for membership expiration after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMembershipExpired();
    });
  }

  @override
  void dispose() {
    tabNotifier.removeListener(_onTabNotifierChanged);
    _badgeSub?.cancel();
    _transitionController.dispose();
    super.dispose();
  }

  /// Responds to tabNotifier changes (triggered by HunterBottomNav in
  /// pushed routes like CreateDuelScreen).
  void _onTabNotifierChanged() {
    final newIndex = tabNotifier.value;
    if (newIndex == 3) {
      // Duels tab selected from a pushed route — _openDuels() is already
      // called by _onDestinationSelected when tapped from MainShell itself,
      // so only trigger here if we're not already opening duels.
      if (!_isOpeningDuels) _openDuels();
    } else if (newIndex != _index) {
      _transitionController.value = 0;
      setState(() => _index = newIndex);
      _transitionController.forward();
    }
  }

  /// Called when a destination is selected on the bottom nav (from MainShell).
  void _onDestinationSelected(int i) {
    if (i == 3) {
      tabNotifier.value = 3; // Keep tabNotifier in sync for pushed routes.
      _openDuels();
      return;
    }
    if (i != _index) {
      tabNotifier.value = i; // Keep tabNotifier in sync.
      _transitionController.value = 0;
      setState(() => _index = i);
      _transitionController.forward();
    }
  }

  /// Shows a one-time dialog if the user's membership has expired since
  /// their last session. The flag is consumed so the dialog never repeats
  /// for the same expiration event.
  void _checkMembershipExpired() {
    final expiredTier = MembershipService.instance.consumeExpiredTier();
    if (expiredTier == null || !mounted) return;

    final tierName = expiredTier == MembershipTier.pro ? 'PRO' : 'MAX';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Text(
              '\u2694\uFE0F Membership Expired',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your $tierName membership has ended.\nWatch rewarded ads to unlock premium benefits again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MembershipScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: HunterTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Renew Membership',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Maybe Later',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  late final List<Widget> _tabs = [
    HomeDashboardScreen(
      fatLoss: widget.fatLoss,
      discipline: widget.discipline,
      muscleGain: widget.muscleGain,
      selfImprovement: widget.selfImprovement,
      bioQuests: widget.bioQuests,
    ),
    MissionsScreen(
      fatLoss: widget.fatLoss,
      discipline: widget.discipline,
      muscleGain: widget.muscleGain,
      selfImprovement: widget.selfImprovement,
      bioQuests: widget.bioQuests,
    ),
    const GlobalRankingsScreen(),
    const SizedBox.shrink(), // Duels = push action (see _openDuels)
    const ProfileScreen(),
  ];

  // Preserves the original Dashboard duel-routing behavior verbatim:
  // active duel -> DuelScreen, pending request -> DuelRequestScreen,
  // otherwise -> CreateDuelScreen. Pushed as a route (keeps its own AppBar).
  Future<void> _openDuels() async {
    if (_isOpeningDuels) return;
    _isOpeningDuels = true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _isOpeningDuels = false; return; }
    try {
      bool hasActiveDuel = false;
      String? duelId;

      // 1) Look for a currently active duel first.
      final activeSnapshot = await FirebaseFirestore.instance
          .collection('duels')
          .where('participants', arrayContains: user.uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (activeSnapshot.docs.isNotEmpty) {
        hasActiveDuel = true;
        duelId = activeSnapshot.docs.first.id;
      } else {
        // 2) No active duel — check for a completed duel this user hasn't
        //    viewed the result of yet.
        final completedSnapshot = await FirebaseFirestore.instance
            .collection('duels')
            .where('participants', arrayContains: user.uid)
            .where('status', isEqualTo: 'completed')
            .limit(10)
            .get();

        for (final doc in completedSnapshot.docs) {
          final data = doc.data();
          final bool isPlayer1 = data['player1'] == user.uid;
          final bool shouldShowResult = isPlayer1
              ? data['player1ViewedResult'] == false
              : data['player2ViewedResult'] == false;
          if (shouldShowResult) {
            hasActiveDuel = true;
            duelId = doc.id;
            break;
          }
        }
      }

      if (!mounted) return;
      if (hasActiveDuel) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => DuelScreen(duelId: duelId!)));
        return;
      }
      final pendingRequest = await FirebaseFirestore.instance
          .collection('duel_requests')
          .where('toUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      if (!mounted) return;
      if (pendingRequest.docs.isNotEmpty) {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => const DuelRequestScreen()));
        return;
      }
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => const CreateDuelScreen()));
    } catch (e) {
      debugPrint("openDuels: $e");
    } finally {
      _isOpeningDuels = false;
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
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: IndexedStack(index: _index, children: _tabs),
        ),
      ),
      bottomNavigationBar: HunterBottomNav(
        selectedIndex: _index,
        showDuelBadge: _hasDuelBadge,
        onDestinationSelected: _onDestinationSelected,
      ),
    );
  }
}

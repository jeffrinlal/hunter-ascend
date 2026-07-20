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
import 'package:hunter_ascend/widgets/daily_motivation_dialog.dart';

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

  // Cached stream for the duel-request notification badge (stable identity).
  late final Stream<QuerySnapshot> _duelRequestBadgeStream = FirebaseFirestore
      .instance
      .collection('duel_requests')
      .where('toUid', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
      .where('status', isEqualTo: 'pending')
      .limit(1)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _transitionController.value = 1.0; // Start fully visible (no animation on first render).
    // Check for membership expiration after the first frame renders.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkMembershipExpired();
      _showDailyMotivation();
    });
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
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

  /// Shows the daily morning motivation dialog if the user hasn't
  /// claimed today's reward yet.
  void _showDailyMotivation() {
    // Slight delay so the membership dialog (if any) appears first.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      DailyMotivationDialog.showIfEligible(context);
    });
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
    const CreateDuelScreen(), // Duels tab (same pattern as other tabs)
    const ProfileScreen(),
  ];

  // Checks for active duel or pending request. If found, pushes on top.
  // Otherwise just switches to the Duels tab (CreateDuelScreen).
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
      // No active duel or pending request — switch to the Duels tab.
      if (_index != 3) {
        _transitionController.value = 0;
        setState(() => _index = 3);
        _transitionController.forward();
      }
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
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  // ── Navigation tap handling ───────────────────────────────────────────────
  //
  // Navigation logic is UNCHANGED — this is the exact behaviour previously in
  // NavigationBar.onDestinationSelected, moved into a named method so the new
  // presentation layer can call it.
  void _onNavTap(int i) {
    if (i == 3) {
      _openDuels();
      return;
    }
    if (i != _index) {
      _transitionController.value = 0;
      setState(() => _index = i);
      _transitionController.forward();
    }
  }

  // ── Premium floating bottom navigation (presentation only) ────────────────
  //
  // A rounded, floating bar that matches the app's premium design language:
  // theme-aware surface + border, soft elevation + accent glow, and an animated
  // gradient "pill" behind the active tab's icon. Fully theme-aware (reads
  // HunterTheme tokens incl. primaryGradient / glowStrength) and responsive
  // (equal Expanded cells, SafeArea-aware so it clears the home indicator and
  // landscape notches).
  Widget _buildBottomNav(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              HunterTheme.primary.withOpacity(0.05),
              HunterTheme.cardColor,
            ],
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: HunterTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(HunterTheme.isDark ? 0.38 : 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: HunterTheme.primary.withOpacity(0.10 * HunterTheme.glowStrength),
              blurRadius: 22,
              spreadRadius: -4,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _navItem(index: 0, icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Home'),
            _navItem(index: 1, icon: Icons.checklist_outlined, selectedIcon: Icons.checklist_rounded, label: 'Missions'),
            _navItem(index: 2, icon: Icons.leaderboard_outlined, selectedIcon: Icons.leaderboard_rounded, label: 'Leaderboard'),
            _navItem(index: 3, icon: Icons.sports_kabaddi_rounded, selectedIcon: Icons.sports_kabaddi_rounded, label: 'Duels', showDuelBadge: true),
            _navItem(index: 4, icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    bool showDuelBadge = false,
  }) {
    final selected = _index == index;
    final accent = HunterTheme.primary;
    final iconColor = selected ? Colors.black : HunterTheme.textSecondary;

    // Icon (with the unchanged duel-request badge overlay for the Duels tab).
    Widget iconGlyph = Icon(selected ? selectedIcon : icon, size: 23, color: iconColor);
    if (showDuelBadge) {
      iconGlyph = StreamBuilder<QuerySnapshot>(
        stream: _duelRequestBadgeStream,
        builder: (context, snap) {
          final hasPending = snap.hasData && snap.data!.docs.isNotEmpty;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(selected ? selectedIcon : icon, size: 23, color: iconColor),
              if (hasPending)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: HunterTheme.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? accent : HunterTheme.cardColor,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onNavTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating active pill behind the icon (animates on selection).
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.symmetric(horizontal: selected ? 20 : 12, vertical: 7),
                decoration: BoxDecoration(
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: HunterTheme.primaryGradient,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: accent.withOpacity(0.38 * HunterTheme.glowStrength),
                            blurRadius: 14,
                            spreadRadius: 0.5,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: iconGlyph,
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? accent : HunterTheme.textTertiary,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
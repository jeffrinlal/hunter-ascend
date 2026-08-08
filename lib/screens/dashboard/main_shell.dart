import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/screens/dashboard/home_dashboard_screen.dart';
import 'package:hunter_ascend/screens/dashboard/missions_screen.dart';
import 'package:hunter_ascend/screens/leaderboard/global_rankings_screen.dart';
import 'package:hunter_ascend/screens/profile/profile_screen.dart';
import 'package:hunter_ascend/screens/battle/battle_hub_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_screen.dart';
import 'package:hunter_ascend/screens/duel/duel_request_screen.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/screens/profile/membership_screen.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/widgets/daily_motivation_dialog.dart';
import 'package:hunter_ascend/widgets/premium_dialog.dart';
import 'package:hunter_ascend/widgets/membership/membership_bottom_nav.dart';

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

  // Notifies child tabs (currently just the Leaderboard) of the active
  // bottom-nav index so they can react to becoming visible — e.g. to run a
  // one-time-per-visit background refresh — without IndexedStack forcing a
  // full widget rebuild of every tab. Value always mirrors [_index] — seeded
  // from [_index] itself (rather than a hardcoded 0) so this stays correct
  // even if [_index]'s initial value is ever driven by restored navigation
  // state instead of always starting at 0.
  late final ValueNotifier<int> _activeTabIndex = ValueNotifier<int>(_index);

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
    _activeTabIndex.dispose();
    super.dispose();
  }

  // ── Single source of truth for active-tab changes ─────────────────────
  //
  // Every navigation path that changes which tab is showing MUST go through
  // this method instead of assigning `_index` directly. It keeps `_index`
  // (drives IndexedStack + bottom-nav highlight) and `_activeTabIndex`
  // (drives the Leaderboard's "became visible" refresh signal) permanently
  // in lockstep, so they can never drift out of sync again — the bug that
  // previously required patching each call site individually.
  void _setActiveTab(int index) {
    if (index == _index) return; // Already active — nothing to do.
    _transitionController.value = 0;
    setState(() => _index = index);
    _transitionController.forward();
    _activeTabIndex.value = index;
  }

  /// Shows a one-time dialog if the user's membership has expired since
  /// their last session. The flag is consumed so the dialog never repeats
  /// for the same expiration event.
  void _checkMembershipExpired() {
    final expiredTier = MembershipService.instance.consumeExpiredTier();
    if (expiredTier == null || !mounted) return;

    final tierName = expiredTier == MembershipTier.pro ? 'PRO' : 'MAX';

    showPremiumDialog(
      context: context,
      builder: (ctx) => PremiumDialogCard(
        icon: Icons.workspace_premium_rounded,
        accent: HunterTheme.gold,
        title: 'Membership Expired',
        message:
            'Your $tierName membership has ended.\nWatch rewarded ads to unlock premium benefits again.',
        actions: [
          PremiumDialogButton.secondary(
            'Maybe Later',
            onTap: () => Navigator.of(ctx).pop(),
          ),
          PremiumDialogButton.primary(
            'Renew',
            icon: Icons.workspace_premium_rounded,
            onTap: () {
              Navigator.of(ctx).pop();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MembershipScreen(),
                ),
              );
            },
          ),
        ],
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
    GlobalRankingsScreen(activeIndex: _activeTabIndex, tabIndex: 2),
    const BattleHubScreen(), // Duels tab → Battle Hub (mode chooser)
    const ProfileScreen(),
  ];

  // Checks for active duel or pending request. If found, pushes on top.
  // Otherwise just switches to the Duels tab (Battle Hub).
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
      _setActiveTab(3);
    } catch (e) {
      debugPrint("openDuels: $e");
    } finally {
      _isOpeningDuels = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // tierNotifier is merged in so the membership-aware chrome (ambient
      // background + bottom nav) instantly re-skins when the tier changes —
      // no app restart, and no rebuilds unless the tier actually changes.
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipService.instance.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    // Each tab screen is itself membership-aware (via MembershipScaffold or its
    // own Pro/Max layout), so no ambient layer is needed behind the stack —
    // that would only paint a gradient hidden under every tab's opaque body.
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
    _setActiveTab(i);
  }

  // ── Membership-aware floating bottom navigation (presentation only) ──────
  //
  // Navigation logic is UNCHANGED — taps still route through [_onNavTap].
  // The presentation (surface tint, border, active pill gradient and glow)
  // is resolved from the current membership tier by [MembershipBottomNav]:
  // Basic keeps the stock look, Pro gets the gold treatment, Max the purple
  // luxury treatment with glow.
  Widget _buildBottomNav(BuildContext context) {
    return MembershipBottomNav(
      selectedIndex: _index,
      onDestinationSelected: _onNavTap,
      items: [
        const MembershipNavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home_rounded,
          label: 'Home',
        ),
        const MembershipNavItem(
          icon: Icons.checklist_outlined,
          selectedIcon: Icons.checklist_rounded,
          label: 'Missions',
        ),
        const MembershipNavItem(
          icon: Icons.leaderboard_outlined,
          selectedIcon: Icons.leaderboard_rounded,
          label: 'Leaderboard',
        ),
        MembershipNavItem(
          icon: Icons.sports_kabaddi_rounded,
          selectedIcon: Icons.sports_kabaddi_rounded,
          label: 'Duels',
          badge: _duelRequestBadge(selected: _index == 3),
        ),
        const MembershipNavItem(
          icon: Icons.person_outline_rounded,
          selectedIcon: Icons.person_rounded,
          label: 'Profile',
        ),
      ],
    );
  }

  /// The unchanged duel-request badge overlay for the Duels tab: a small
  /// danger dot shown while a pending duel request exists.
  Widget _duelRequestBadge({required bool selected}) {
    final accent = MembershipTheme.current.accent;
    return StreamBuilder<QuerySnapshot>(
      stream: _duelRequestBadgeStream,
      builder: (context, snap) {
        final hasPending = snap.hasData && snap.data!.docs.isNotEmpty;
        if (!hasPending) return const SizedBox.shrink();
        return Container(
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
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/data/models/fitness_plan.dart';
import 'package:hunter_ascend/screens/profile/plan_viewer_screen.dart';
import 'package:hunter_ascend/services/plan_shop_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';
import 'package:hunter_ascend/widgets/membership/membership_app_bar.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';
import 'package:hunter_ascend/widgets/membership/membership_scaffold.dart';

/// Shop screen for unlockable PDF fitness plans (rewarded-ad model).
///
/// Displays a [TabBar] with one tab per goal (plus "All"), showing plan
/// cards with locked / unlocked / expired state. Tapping a locked plan
/// triggers the same rewarded ad flow used by the membership screen; on
/// ad completion, [PlanShopService] writes the unlock document with a
/// data-driven expiry (`unlockedAt + plan.durationDays`).
///
/// Unlocked & non-expired plans open [PlanViewerScreen]. Expired plans
/// show a "watch ad to unlock again" prompt.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

/// State of the rewarded ad button (reuses the membership screen's pattern).
enum _AdButtonState { loading, ready, unavailable }

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Rewarded ad manager — reuses the same ad unit as the membership screen.
  late final RewardedAdManager _adManager;

  /// The plan id currently being unlocked (after ad completion).
  String? _unlockingPlanId;

  // Stable identity for the pre-existing planUnlocks listener.
  //
  // The stream used to be constructed inline inside build(), so every rebuild
  // handed StreamBuilder a NEW Stream object, making it cancel and
  // re-subscribe (re-priming the whole query). This screen rebuilds on
  // theme-notifier changes and on setState from its ad manager.
  //
  // Memoised per uid — same collection, same query, still exactly ONE
  // listener; only the object identity is now stable across rebuilds.
  // Mirrors MainShell's cached-stream approach.
  String? _planUnlocksUid;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _planUnlocksStream;

  Stream<QuerySnapshot<Map<String, dynamic>>> _planUnlocksStreamFor(String uid) {
    if (_planUnlocksStream == null || _planUnlocksUid != uid) {
      _planUnlocksUid = uid;
      _planUnlocksStream = FirebaseFirestore.instance
          .collection('hunters')
          .doc(uid)
          .collection('planUnlocks')
          .snapshots();
    }
    return _planUnlocksStream!;
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 5, vsync: this);

    _adManager = RewardedAdManager(
      onAdStatusChanged: () {
        if (mounted) setState(() {});
      },
    );

    _adManager.loadAd();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Ad Button State ────────────────────────────────────────────────────

  _AdButtonState _adStateFromManager() {
    if (_adManager.isReady) return _AdButtonState.ready;
    if (_adManager.isLoading) return _AdButtonState.loading;
    return _AdButtonState.unavailable;
  }

  // ── Rewarded Ad Flow ───────────────────────────────────────────────────

  /// Shows the rewarded ad, then claims the unlock for [plan] on completion.
  void _showAdForPlan(FitnessPlan plan) {
    if (_unlockingPlanId != null) return;

    _adManager.showAd(
      onRewardEarned: () => _claimUnlock(plan),
      onAdDismissed: () {
        if (mounted) setState(() {});
      },
      onAdFailed: () {
        if (mounted) {
          _showErrorSnackBar('Could not show rewarded ad. Please try again.');
        }
      },
    );
    setState(() {});
  }

  /// Calls [PlanShopService] to write the unlock document.
  Future<void> _claimUnlock(FitnessPlan plan) async {
    if (!mounted) return;
    setState(() => _unlockingPlanId = plan.id);

    final result = await PlanShopService.instance.claimPlanUnlock(plan);

    if (!mounted) return;

    setState(() => _unlockingPlanId = null);

    if (result.wasUnlocked) {
      _showSuccessSnackBar(
        '${plan.title} unlocked for ${plan.durationDays} days!',
      );
    } else {
      _showErrorSnackBar(result.message ?? 'Failed to unlock plan.');
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────

  void _openPlanViewer(FitnessPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanViewerScreen(plan: plan),
      ),
    );
  }

  // ── Snackbars ──────────────────────────────────────────────────────────

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.success.withOpacity(0.5)),
        ),
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded,
                color: HunterTheme.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.danger.withOpacity(0.5)),
        ),
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded,
                color: HunterTheme.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      // tierNotifier merged so the membership chrome (scaffold glow + app
      // bar + plan cards) re-skins instantly on membership change.
      listenable: Listenable.merge([
        themeNotifier,
        ThemeService.instance.activeThemeNotifier,
        MembershipTheme.tierNotifier,
      ]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    return MembershipScaffold(
      appBar: const MembershipAppBar(title: 'FITNESS PLANS'),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(),
            const SizedBox(height: 8),
            Expanded(child: _buildUnlockStream()),
          ],
        ),
      ),
    );
  }

  // ── Tab Bar ────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    final tabs = [
      const Tab(text: 'All', icon: Icon(Icons.grid_view_rounded, size: 18)),
      Tab(
          text: FitnessGoal.weightLoss.label,
          icon: Icon(FitnessGoal.weightLoss.icon, size: 18)),
      Tab(
          text: FitnessGoal.weightGain.label,
          icon: Icon(FitnessGoal.weightGain.icon, size: 18)),
      Tab(
          text: FitnessGoal.muscleBuild.label,
          icon: Icon(FitnessGoal.muscleBuild.icon, size: 18)),
      Tab(
          text: FitnessGoal.athleteBody.label,
          icon: Icon(FitnessGoal.athleteBody.icon, size: 18)),
    ];

    return MembershipSurface(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      radius: 14,
      padding: EdgeInsets.zero,
      child: TabBar(
        controller: _tabController,
        tabs: tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: MembershipTheme.current.accent,
        unselectedLabelColor: HunterTheme.textSecondary,
        labelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w800),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: MembershipTheme.current.accent.withOpacity(0.12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        padding: const EdgeInsets.all(4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    );
  }

  // ── Unlock Stream ───────────────────────────────────────────────────────

  /// Listens to the entire `planUnlocks` subcollection so all plan cards
  /// update reactively when an unlock is written.
  Widget _buildUnlockStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return _buildAuthPrompt();
    }

    // Same single pre-existing snapshot stream on the planUnlocks
    // subcollection — hoisted so its identity is stable across rebuilds
    // (see _planUnlocksStreamFor). No additional listener or read is added.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _planUnlocksStreamFor(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
                color: MembershipTheme.current.accent),
          );
        }

        // Build a map of planId → unlock state from the snapshot.
        final Map<String, PlanUnlockState> unlockMap = {};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final state =
                PlanShopService.stateFromSnapshot(doc);
            if (state != null) {
              unlockMap[doc.id] = state;
            }
          }
        }

        return TabBarView(
          controller: _tabController,
          children: [
            _buildPlanGrid(PlanCatalog.all, unlockMap),
            _buildPlanGrid(
                PlanCatalog.byGoal(FitnessGoal.weightLoss), unlockMap),
            _buildPlanGrid(
                PlanCatalog.byGoal(FitnessGoal.weightGain), unlockMap),
            _buildPlanGrid(
                PlanCatalog.byGoal(FitnessGoal.muscleBuild), unlockMap),
            _buildPlanGrid(
                PlanCatalog.byGoal(FitnessGoal.athleteBody), unlockMap),
          ],
        );
      },
    );
  }

  Widget _buildAuthPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline,
                size: 48, color: HunterTheme.textFaint),
            const SizedBox(height: 16),
            Text(
              'Sign in to unlock plans',
              style: TextStyle(
                color: HunterTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan Grid ──────────────────────────────────────────────────────────

  Widget _buildPlanGrid(
      List<FitnessPlan> plans, Map<String, PlanUnlockState> unlockMap) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        final unlock = unlockMap[plan.id];
        return _PlanCard(
          plan: plan,
          unlock: unlock,
          adButtonState: _adStateFromManager(),
          isUnlocking: _unlockingPlanId == plan.id,
          onWatchAd: () => _showAdForPlan(plan),
          onOpen: () => _openPlanViewer(plan),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan Card
// ─────────────────────────────────────────────────────────────────────────────

/// A single plan card showing title, duration badge, and lock/unlock state.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.unlock,
    required this.adButtonState,
    required this.isUnlocking,
    required this.onWatchAd,
    required this.onOpen,
  });

  final FitnessPlan plan;
  final PlanUnlockState? unlock;
  final _AdButtonState adButtonState;
  final bool isUnlocking;
  final VoidCallback onWatchAd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = plan.goal.accentColor;
    final isActive = unlock?.isActive ?? false;
    final isExpired = unlock?.isExpired ?? false;
    final cardRadius = MembershipTheme.current.cardRadius;

    return MembershipCard(
      padding: EdgeInsets.zero,
      borderColor: isActive ? accent.withOpacity(0.5) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(cardRadius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header (goal icon + duration badge) ──
            _buildHeader(accent, isActive),
            // ── Body (title + description) ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.title,
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plan.durationDays} day plan',
                      style: TextStyle(
                        color: HunterTheme.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    // ── Action area (pinned to bottom) ──
                    if (isActive)
                      _buildUnlockedButton(accent)
                    else if (isExpired)
                      _buildExpiredPrompt(accent)
                    else
                      _buildLockedButton(accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color accent, bool isActive) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(isActive ? 0.22 : 0.10),
            accent.withOpacity(isActive ? 0.06 : 0.02),
          ],
        ),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              plan.goal.icon,
              size: 28,
              color: accent.withOpacity(0.7),
            ),
          ),
          Positioned(
            top: 6,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: HunterTheme.cardColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Text(
                plan.duration.badge,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          if (isActive)
            Positioned(
              top: 6,
              left: 8,
              child: Icon(
                Icons.lock_open_rounded,
                size: 14,
                color: HunterTheme.success,
              ),
            )
          else
            Positioned(
              top: 6,
              left: 8,
              child: Icon(
                Icons.lock_rounded,
                size: 14,
                color: HunterTheme.textFaint,
              ),
            ),
        ],
      ),
    );
  }

  // ── Unlocked: tap to open the PDF viewer ──
  Widget _buildUnlockedButton(Color accent) {
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [accent, accent.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: accent.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('\u{1F4C4}', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'View Plan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Expired: show "unlock again" prompt ──
  Widget _buildExpiredPrompt(Color accent) {
    return Column(
      children: [
        Text(
          'Access expired',
          style: TextStyle(
            color: HunterTheme.danger,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        _RewardedAdButton(
          state: isUnlocking ? _AdButtonState.loading : adButtonState,
          label: 'Unlock Again',
          accentColor: accent,
          onTap: onWatchAd,
          onRetry: null,
          compact: true,
        ),
      ],
    );
  }

  // ── Locked: show "watch ad to unlock" button ──
  Widget _buildLockedButton(Color accent) {
    return _RewardedAdButton(
      state: isUnlocking ? _AdButtonState.loading : adButtonState,
      label: 'Watch Ad',
      accentColor: accent,
      onTap: onWatchAd,
      onRetry: null,
      compact: true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rewarded Ad Button (reuses the membership screen's 3-state pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _RewardedAdButton extends StatelessWidget {
  const _RewardedAdButton({
    required this.state,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.onRetry,
    this.compact = false,
  });

  final _AdButtonState state;
  final String label;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _AdButtonState.loading:
        return _buildDisabled(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: compact ? 12 : 14,
                height: compact ? 12 : 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HunterTheme.textFaint,
                  semanticsLabel: 'Loading rewarded ad',
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Loading...',
                style: TextStyle(
                  color: HunterTheme.textFaint,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case _AdButtonState.unavailable:
        return Column(
          children: [
            _buildDisabled(
              child: Text(
                'Ad Unavailable',
                style: TextStyle(
                  color: HunterTheme.textFaint,
                  fontSize: compact ? 12 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: onRetry,
                child: Text(
                  'Tap to retry',
                  style: TextStyle(
                    color: MembershipTheme.current.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        );

      case _AdButtonState.ready:
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('\u{1F3A5}', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 12 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildDisabled({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
      decoration: BoxDecoration(
        color: HunterTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HunterTheme.border),
      ),
      child: Center(child: child),
    );
  }
}

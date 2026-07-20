import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/theme_service.dart';
import 'package:hunter_ascend/services/membership_service.dart';
import 'package:hunter_ascend/services/membership_reward_service.dart';
import 'package:hunter_ascend/services/rewarded_ad_manager.dart';

/// State of the rewarded ad button.
enum _AdButtonState {
  /// Ad is loading and not yet available.
  loading,

  /// Ad is ready to be watched.
  ready,

  /// Ad is unavailable (no fill, network error, etc.).
  unavailable,
}

/// Membership screen — rewarded ad model (Phase 11.3).
///
/// Displays Basic / Pro / Max plan cards. Pro and Max use real AdMob
/// rewarded ads. On reward earned, calls [MembershipRewardService] to
/// securely grant membership time via Cloud Functions.
///
/// This screen NEVER grants membership directly.
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}


class _MembershipScreenState extends State<MembershipScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final List<Animation<double>> _cardFade;
  late final List<Animation<Offset>> _cardSlide;

  /// Rewarded ad manager (single instance for both Pro and Max).
  late final RewardedAdManager _adManager;

  /// Max pending progress (0 = no ads watched, 1 = first ad done).
  int _maxPendingAds = 0;

  /// Whether a claim is currently being processed.
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    const cardCount = 3;
    _cardFade = List.generate(cardCount, (index) {
      final start = index * 0.15;
      final end = (start + 0.6).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _entranceController,
        curve: Interval(start, end, curve: Curves.easeOut),
      );
    });

    _cardSlide = List.generate(cardCount, (index) {
      final start = index * 0.15;
      final end = (start + 0.6).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.12),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _entranceController,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });

    // Initialize ad manager (single instance for both Pro and Max).
    _adManager = RewardedAdManager(
      onAdStatusChanged: () { if (mounted) setState(() {}); },
    );

    // Load membership and ads.
    MembershipService.instance.loadMembership().whenComplete(() {
      if (mounted) setState(() {});
    });

    _adManager.loadAd();

    _entranceController.forward();
  }

  @override
  void dispose() {
    _adManager.dispose();
    _entranceController.dispose();
    super.dispose();
  }


  // ── Ad Button State ────────────────────────────────────────────────────

  _AdButtonState _adStateFromManager(RewardedAdManager manager) {
    if (manager.isReady) return _AdButtonState.ready;
    if (manager.isLoading) return _AdButtonState.loading;
    return _AdButtonState.unavailable;
  }

  // ── Rewarded Ad Flows ──────────────────────────────────────────────────

  /// Shows the rewarded ad, then claims the reward for the given type.
  void _showAdForTier(String membershipType) {
    if (_isClaiming) return;

    _adManager.showAd(
      onRewardEarned: () => _claimReward(membershipType),
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

  /// Shows Pro rewarded ad, then claims the reward on completion.
  void _onWatchProAd() => _showAdForTier('pro');

  /// Shows Max rewarded ad, then claims the reward on completion.
  void _onWatchMaxAd() => _showAdForTier('max');

  /// Calls MembershipRewardService to securely claim the reward.
  Future<void> _claimReward(String membershipType) async {
    if (!mounted) return;
    setState(() => _isClaiming = true);

    final result =
        await MembershipRewardService.instance.claimReward(membershipType);

    if (!mounted) return;

    if (result.success) {
      if (result.isPendingMax) {
        // First Max ad done — update progress.
        setState(() {
          _maxPendingAds = 1;
          _isClaiming = false;
        });
        _showSuccessSnackBar('1/2 ads completed. Watch one more for +1 day Max!');
      } else if (result.wasExtended) {
        // Membership time granted.
        setState(() {
          _maxPendingAds = 0;
          _isClaiming = false;
        });
        _showSuccessSnackBar(
          '${result.membershipType == "pro" ? "Pro" : "Max"} '
          'membership extended by +1 day!',
        );
      } else {
        setState(() => _isClaiming = false);
      }
    } else {
      setState(() => _isClaiming = false);
      _showErrorSnackBar(result.message ?? 'Failed to claim reward.');
    }
  }


  // ── Switching Membership Confirmation ────────────────────────────────────

  void _showSwitchConfirmation({required MembershipTier targetTier}) {
    final membership = MembershipService.instance;
    final currentName = membership.membershipName;
    final targetName = targetTier == MembershipTier.pro ? 'Pro' : 'Max';

    final expiry = membership.membershipExpiry;
    String remainingText = '';
    if (expiry != null && expiry.isAfter(DateTime.now())) {
      final diff = expiry.difference(DateTime.now());
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      remainingText = '$days day${days != 1 ? 's' : ''}';
      if (hours > 0) remainingText += ' $hours hour${hours != 1 ? 's' : ''}';
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: HunterTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Switch Membership?',
          style: TextStyle(
            color: HunterTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (remainingText.isNotEmpty)
              Text(
                'You currently have $remainingText of $currentName Membership remaining.',
                style: TextStyle(
                  color: HunterTheme.textSecondary, fontSize: 14, height: 1.5,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'Switching to $targetName will permanently remove your remaining $currentName Membership.',
              style: TextStyle(
                color: HunterTheme.textSecondary, fontSize: 14, height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: HunterTheme.danger, fontSize: 13, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: HunterTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (targetTier == MembershipTier.pro) {
                _onWatchProAd();
              } else {
                _onWatchMaxAd();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: targetTier == MembershipTier.pro
                  ? HunterTheme.gold : HunterTheme.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Switch to $targetName',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _handleAdButtonTap(MembershipTier targetTier) {
    final membership = MembershipService.instance;
    final bool isSwitching = (targetTier == MembershipTier.pro && membership.isMax) ||
        (targetTier == MembershipTier.max && membership.isPro);

    if (isSwitching) {
      _showSwitchConfirmation(targetTier: targetTier);
      return;
    }

    if (targetTier == MembershipTier.pro) {
      _onWatchProAd();
    } else {
      _onWatchMaxAd();
    }
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
            Icon(Icons.check_circle_rounded, color: HunterTheme.success, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 13)),
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
            Icon(Icons.error_outline_rounded, color: HunterTheme.danger, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: HunterTheme.textPrimary,
                      fontWeight: FontWeight.w600, fontSize: 13)),
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
      listenable: Listenable.merge([themeNotifier, ThemeService.instance.activeThemeNotifier]),
      builder: (context, _) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final membership = MembershipService.instance;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    final adState = _adStateFromManager(_adManager);

    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(title: const Text('MEMBERSHIP'), centerTitle: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxContentWidth = isTablet ? 720.0 : double.infinity;
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(),
                      const SizedBox(height: 24),
                      _CurrentPlanBanner(membership: membership),
                      const SizedBox(height: 16),

                      // ── Basic Mode Toggle ──
                      if (membership.actualTier != MembershipTier.basic)
                        _BasicModeToggle(
                          isBasicMode: membership.isBasicModeActive,
                          actualTierName: membership.actualTier == MembershipTier.max ? 'Max' : 'Pro',
                          onToggle: () async {
                            if (membership.isBasicModeActive) {
                              await membership.disableBasicMode();
                            } else {
                              await membership.enableBasicMode();
                            }
                            if (mounted) setState(() {});
                          },
                        ),

                      const SizedBox(height: 28),

                      // ── Basic Card ──
                      _AnimatedPlanCard(
                        fade: _cardFade[0],
                        slide: _cardSlide[0],
                        child: _AdPlanCard(
                          icon: Icons.shield_outlined,
                          accentColor: HunterTheme.textSecondary,
                          title: 'Basic',
                          subtitle: 'FREE',
                          isCurrent: membership.isBasic,
                          features: const [
                            'Daily AI-generated missions',
                            'Weekly missions',
                            'Run tracking & XP',
                            'Calorie tracking',
                            'Default avatar frame',
                            'Banner ads',
                            'Rewarded ads',
                          ],
                          adButton: null,
                        ),
                      ),
                      const SizedBox(height: 20),


                      // ── Pro Card ──
                      _AnimatedPlanCard(
                        fade: _cardFade[1],
                        slide: _cardSlide[1],
                        child: _AdPlanCard(
                          icon: Icons.workspace_premium_rounded,
                          accentColor: HunterTheme.gold,
                          title: 'Pro',
                          subtitle: 'Watch 1 Ad = +1 Day',
                          isCurrent: membership.isPro,
                          features: const [
                            'Remove banner ads',
                            '1 Premium Report Generation',
                            'Unlimited profile changes',
                            'Gold badge on leaderboard',
                            'Gold avatar frame',
                            'Gold avatar glow',
                          ],
                          adButton: _RewardedAdButton(
                            state: _isClaiming ? _AdButtonState.loading : adState,
                            label: 'Watch 1 Ad',
                            sublabel: '+1 Day',
                            accentColor: HunterTheme.gold,
                            onTap: () => _handleAdButtonTap(MembershipTier.pro),
                            onRetry: _adManager.retry,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Max Card ──
                      _AnimatedPlanCard(
                        fade: _cardFade[2],
                        slide: _cardSlide[2],
                        child: _AdPlanCard(
                          icon: Icons.auto_awesome_rounded,
                          accentColor: HunterTheme.purple,
                          title: 'Max',
                          subtitle: 'Watch 2 Ads = +1 Day',
                          isCurrent: membership.isMax,
                          features: const [
                            'Everything in Pro',
                            'Remove banner ads',
                            'Unlimited Premium Report Generation',
                            'Animated avatar frame',
                            'Animated avatar glow',
                            'Monthly rewarded ad skips',
                            'Unlimited profile changes',
                          ],
                          adButton: _RewardedAdButton(
                            state: _isClaiming ? _AdButtonState.loading : adState,
                            label: _maxPendingAds >= 1 ? 'Watch Ad 2/2' : 'Watch Ad 1/2',
                            sublabel: _maxPendingAds >= 1 ? '+1 Day' : 'Progress',
                            accentColor: HunterTheme.purple,
                            onTap: () => _handleAdButtonTap(MembershipTier.max),
                            onRetry: _adManager.retry,
                          ),
                          progressText: _maxPendingAds >= 1
                              ? '1/2 ads completed. Watch one more to earn +1 day of Max Membership.'
                              : 'Watch 2 rewarded ads to earn +1 day of Max Membership.',
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Disclaimer ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: HunterTheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: HunterTheme.border),
                        ),
                        child: Text(
                          'Membership time is earned by watching rewarded ads. '
                          'Each completed ad adds time to your membership. '
                          'Membership benefits expire when your accumulated time runs out.',
                          style: TextStyle(
                            color: HunterTheme.textTertiary,
                            fontSize: 11,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}



// ══════════════════════════════════════════════════════════════════════════════
// EXTRACTED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

/// Screen header.
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HunterTheme.primary.withOpacity(0.16),
            HunterTheme.gold.withOpacity(0.10),
            HunterTheme.cardColor,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HunterTheme.gold.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(color: HunterTheme.gold.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [HunterTheme.primary, HunterTheme.gold],
              ),
              boxShadow: [
                BoxShadow(color: HunterTheme.gold.withOpacity(0.45), blurRadius: 20, spreadRadius: 1),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 32),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [HunterTheme.primary, HunterTheme.gold],
            ).createShader(bounds),
            child: const Text(
              'HUNTER MEMBERSHIP',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Unlock premium features and cosmetics by watching rewarded ads.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

/// Displays the hunter's ACTUAL (owned) membership tier with expiry countdown.
/// Uses [actualTier] so that Basic Mode override does not affect the
/// ownership information shown here.
class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.membership});
  final MembershipService membership;

  Color _badgeColor() {
    final tier = membership.actualTier;
    if (tier == MembershipTier.max) return HunterTheme.purple;
    if (tier == MembershipTier.pro) return HunterTheme.gold;
    return HunterTheme.textSecondary;
  }

  IconData _badgeIcon() {
    final tier = membership.actualTier;
    if (tier == MembershipTier.max) return Icons.auto_awesome_rounded;
    if (tier == MembershipTier.pro) return Icons.workspace_premium_rounded;
    return Icons.shield_outlined;
  }

  String _tierName() {
    final tier = membership.actualTier;
    switch (tier) {
      case MembershipTier.max: return 'Max';
      case MembershipTier.pro: return 'Pro';
      case MembershipTier.basic: return 'Basic';
    }
  }

  String? _expiryCountdown() {
    if (membership.actualTier == MembershipTier.basic) return null;
    final expiry = membership.membershipExpiry;
    if (expiry == null) return null;
    final now = DateTime.now();
    if (expiry.isBefore(now)) return 'Expired';
    final diff = expiry.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    if (days == 0 && hours == 0) return 'Less than 1 hour';
    final parts = <String>[];
    if (days > 0) parts.add('$days Day${days != 1 ? 's' : ''}');
    if (hours > 0) parts.add('$hours Hour${hours != 1 ? 's' : ''}');
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor();
    final tier = membership.actualTier;
    final bool hasPremium = tier != MembershipTier.basic;
    final expiry = membership.membershipExpiry;
    final isActive = hasPremium &&
        expiry != null &&
        expiry.isAfter(DateTime.now());
    final countdown = _expiryCountdown();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [badgeColor.withOpacity(0.12), HunterTheme.cardColor],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badgeColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(HunterTheme.isDark ? 0.2 : 0.1),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withOpacity(0.6)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_badgeIcon(), color: badgeColor, size: 15),
              const SizedBox(width: 6),
              Text(
                '${_tierName().toUpperCase()} ${isActive ? "ACTIVE" : ""}',
                style: TextStyle(color: badgeColor, fontSize: 12,
                    fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ]),
          ),
          const Spacer(),
          if (isActive) Container(width: 8, height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: HunterTheme.success)),
        ]),
        if (hasPremium && countdown != null) ...[
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.timer_outlined, color: HunterTheme.textTertiary, size: 14),
            const SizedBox(width: 6),
            Text('Expires in:', style: TextStyle(color: HunterTheme.textTertiary,
                fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Text(countdown, style: TextStyle(color: HunterTheme.textPrimary,
                fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }
}


/// Toggle button for Basic Mode override.
class _BasicModeToggle extends StatelessWidget {
  const _BasicModeToggle({
    required this.isBasicMode,
    required this.actualTierName,
    required this.onToggle,
  });

  final bool isBasicMode;
  final String actualTierName;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = isBasicMode ? HunterTheme.primary : HunterTheme.textSecondary;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              isBasicMode ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: color,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBasicMode
                        ? 'Basic Mode Active'
                        : 'Use Basic Mode',
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isBasicMode
                        ? 'You\'re temporarily using the Basic experience.'
                        : 'Temporarily use the app as a Basic user.',
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isBasicMode ? HunterTheme.primary.withOpacity(0.12) : HunterTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isBasicMode ? HunterTheme.primary.withOpacity(0.4) : HunterTheme.border,
                ),
              ),
              child: Text(
                isBasicMode ? 'Switch Back' : 'Enable',
                style: TextStyle(
                  color: isBasicMode ? HunterTheme.primary : HunterTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Wraps a plan card with staggered fade + slide-up entrance animation.
class _AnimatedPlanCard extends StatelessWidget {
  const _AnimatedPlanCard({
    required this.fade,
    required this.slide,
    required this.child,
  });
  final Animation<double> fade;
  final Animation<Offset> slide;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

/// A plan card for the rewarded-ad membership model.
class _AdPlanCard extends StatefulWidget {
  const _AdPlanCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.isCurrent,
    required this.features,
    this.adButton,
    this.progressText,
  });
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final bool isCurrent;
  final List<String> features;
  final Widget? adButton;
  final String? progressText;

  @override
  State<_AdPlanCard> createState() => _AdPlanCardState();
}


class _AdPlanCardState extends State<_AdPlanCard> {
  bool _hovered = false;
  bool _pressed = false;
  double get _scale => _pressed ? 0.985 : (_hovered ? 1.01 : 1.0);

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent.withOpacity(widget.isCurrent ? 0.14 : 0.07),
                  HunterTheme.cardColor,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: widget.isCurrent ? accent.withOpacity(0.9) : accent.withOpacity(0.28),
                width: widget.isCurrent ? 1.6 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withOpacity(_hovered ? 0.28 : (widget.isCurrent ? 0.22 : 0.12)),
                  blurRadius: _hovered ? 26 : 18,
                  spreadRadius: widget.isCurrent ? 1 : 0,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(HunterTheme.isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent.withOpacity(0.22), accent.withOpacity(0.08)],
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: accent.withOpacity(0.35)),
                    ),
                    child: Icon(widget.icon, color: accent, size: 27),
                  ),


                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(widget.title, style: TextStyle(
                          color: HunterTheme.textPrimary, fontSize: 19,
                          fontWeight: FontWeight.w900, letterSpacing: 0.4)),
                        if (widget.isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: HunterTheme.success.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: HunterTheme.success.withOpacity(0.5)),
                            ),
                            child: Text('CURRENT', style: TextStyle(
                              color: HunterTheme.success, fontSize: 10,
                              fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      Text(widget.subtitle, style: TextStyle(
                        color: accent, fontSize: 14, fontWeight: FontWeight.w700)),
                    ],
                  )),
                ]),
                const SizedBox(height: 18),
                ...widget.features.map((feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent.withOpacity(0.15),
                        border: Border.all(color: accent.withOpacity(0.35)),
                      ),
                      child: Icon(Icons.check_rounded, color: accent, size: 13),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(feature, style: TextStyle(
                      color: HunterTheme.textPrimary.withOpacity(0.85), fontSize: 13.5,
                      fontWeight: FontWeight.w500, height: 1.35))),
                  ]),
                )),
                if (widget.progressText != null) ...[
                  const SizedBox(height: 4),
                  Text(widget.progressText!, style: TextStyle(
                    color: HunterTheme.textTertiary, fontSize: 12,
                    fontStyle: FontStyle.italic, height: 1.4)),
                  const SizedBox(height: 8),
                ],
                if (widget.adButton != null) ...[
                  const SizedBox(height: 8),
                  widget.adButton!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}


/// Rewarded ad button with three states: loading, ready, unavailable.
class _RewardedAdButton extends StatelessWidget {
  const _RewardedAdButton({
    required this.state,
    required this.label,
    required this.sublabel,
    required this.accentColor,
    required this.onTap,
    this.onRetry,
  });
  final _AdButtonState state;
  final String label;
  final String sublabel;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _AdButtonState.loading:
        return _buildDisabled(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: HunterTheme.textFaint,
                semanticsLabel: 'Loading rewarded ad')),
            const SizedBox(width: 10),
            Text('Loading Rewarded Ad...', style: TextStyle(
              color: HunterTheme.textFaint, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        );

      case _AdButtonState.unavailable:
        return Column(children: [
          _buildDisabled(
            child: Text('Rewarded Ad Unavailable', style: TextStyle(
              color: HunterTheme.textFaint, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          Text("Rewarded video isn't available right now. Please try again later.",
            textAlign: TextAlign.center,
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, height: 1.4)),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onRetry,
              child: Text('Tap to retry', style: TextStyle(
                color: HunterTheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ]);


      case _AdButtonState.ready:
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accentColor, accentColor.withOpacity(0.8)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('\u{1F3A5}', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(sublabel, style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        );
    }
  }

  Widget _buildDisabled({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: HunterTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: HunterTheme.border),
      ),
      child: Center(child: child),
    );
  }
}

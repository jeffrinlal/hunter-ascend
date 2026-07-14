import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// State of the rewarded ad button.
enum _AdButtonState {
  /// Ad is loading and not yet available.
  loading,

  /// Ad is ready to be watched.
  ready,

  /// Ad is unavailable (no fill, network error, etc.).
  unavailable,
}

/// Membership screen — rewarded ad model (Phase 11.1).
///
/// Displays Basic / Pro / Max plan cards. Pro and Max use rewarded ads
/// instead of subscriptions. This screen does NOT implement ad logic —
/// it uses placeholder callbacks for future wiring.
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

  /// Rewarded ad button state for Pro card.
  _AdButtonState _proAdState = _AdButtonState.ready;

  /// Rewarded ad button state for Max card.
  _AdButtonState _maxAdState = _AdButtonState.ready;

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

    MembershipService.instance.loadMembership().whenComplete(() {
      if (mounted) setState(() {});
    });

    _entranceController.forward();

    // Placeholder: In production, load rewarded ads here and update
    // _proAdState / _maxAdState accordingly.
    _loadRewardedAds();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }


  // ── Placeholder Ad Logic ─────────────────────────────────────────────────

  /// Placeholder: loads rewarded ads. Replace with actual ad SDK calls.
  void _loadRewardedAds() {
    // In production, this would call the ad SDK to preload rewarded videos
    // and update _proAdState / _maxAdState based on load callbacks.
    // For now, default to ready state.
  }

  /// Placeholder: called when user taps the Pro rewarded ad button.
  void _onWatchProAd() {
    // In production: show rewarded ad, on completion grant +1 day Pro.
    debugPrint('MembershipScreen: Watch Pro ad tapped (placeholder).');
  }

  /// Placeholder: called when user taps the Max rewarded ad button.
  void _onWatchMaxAd() {
    // In production: show first ad, then second ad, on both completions
    // grant +1 day Max.
    debugPrint('MembershipScreen: Watch Max ad tapped (placeholder).');
  }


  // ── Switching Membership Confirmation ────────────────────────────────────

  /// Shows a confirmation dialog when user wants to switch from their
  /// current premium tier to a different premium tier.
  void _showSwitchConfirmation({
    required MembershipTier targetTier,
  }) {
    final membership = MembershipService.instance;
    final currentName = membership.membershipName;
    final targetName = targetTier == MembershipTier.pro ? 'Pro' : 'Max';

    // Calculate remaining days.
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
                  color: HunterTheme.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),


            const SizedBox(height: 12),
            Text(
              'Switching to $targetName will permanently remove your remaining $currentName Membership.',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: HunterTheme.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: HunterTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Proceed with the ad flow for the target tier.
              if (targetTier == MembershipTier.pro) {
                _onWatchProAd();
              } else {
                _onWatchMaxAd();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: targetTier == MembershipTier.pro
                  ? HunterTheme.gold
                  : HunterTheme.purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text('Switch to $targetName',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }


  /// Handles the ad button tap. If user has a different active premium
  /// tier, shows the switch confirmation. Otherwise starts the ad flow.
  void _handleAdButtonTap(MembershipTier targetTier) {
    final membership = MembershipService.instance;

    // Check if user is switching from one premium tier to another.
    final bool isSwitching;
    if (targetTier == MembershipTier.pro && membership.isMax) {
      isSwitching = true;
    } else if (targetTier == MembershipTier.max && membership.isPro) {
      isSwitching = true;
    } else {
      isSwitching = false;
    }

    if (isSwitching) {
      _showSwitchConfirmation(targetTier: targetTier);
      return;
    }

    // Direct flow — no switch needed.
    if (targetTier == MembershipTier.pro) {
      _onWatchProAd();
    } else {
      _onWatchMaxAd();
    }
  }


  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, _, __) => _themedBuild(context),
    );
  }

  Widget _themedBuild(BuildContext context) {
    final membership = MembershipService.instance;
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 700;

    return Scaffold(
      backgroundColor: HunterTheme.background,
      appBar: AppBar(
        title: const Text('MEMBERSHIP'),
        centerTitle: true,
      ),
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
                          adButton: null, // No ad button for Basic.
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
                            state: _proAdState,
                            label: 'Watch 1 Ad',
                            sublabel: '+1 Day',
                            accentColor: HunterTheme.gold,
                            onTap: () => _handleAdButtonTap(MembershipTier.pro),
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
                            state: _maxAdState,
                            label: 'Watch 2 Ads',
                            sublabel: '+1 Day',
                            accentColor: HunterTheme.purple,
                            onTap: () => _handleAdButtonTap(MembershipTier.max),
                          ),
                          progressText:
                              'Watch 2 rewarded ads to earn +1 day of Max Membership.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [HunterTheme.primary, HunterTheme.gold],
          ).createShader(bounds),
          child: const Text(
            'HUNTER MEMBERSHIP',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Watch ads to unlock premium features and cosmetics.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: HunterTheme.textSecondary,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}



/// Displays the hunter's current membership tier with expiry countdown.
class _CurrentPlanBanner extends StatelessWidget {
  const _CurrentPlanBanner({required this.membership});

  final MembershipService membership;

  Color _badgeColor() {
    if (membership.isMax) return HunterTheme.purple;
    if (membership.isPro) return HunterTheme.gold;
    return HunterTheme.textSecondary;
  }

  IconData _badgeIcon() {
    if (membership.isMax) return Icons.auto_awesome_rounded;
    if (membership.isPro) return Icons.workspace_premium_rounded;
    return Icons.shield_outlined;
  }

  /// Returns "X Days Y Hours" remaining, or null.
  String? _expiryCountdown() {
    if (membership.isBasic) return null;
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
    final isActive = membership.hasPremium && membership.subscriptionActive;
    final countdown = _expiryCountdown();

    return Semantics(
      label: 'Current plan: ${membership.membershipName}. '
          '${isActive ? "Active" : ""}. '
          '${countdown != null ? "Expires in $countdown" : ""}',
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: badgeColor.withOpacity(0.6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withOpacity(HunterTheme.isDark ? 0.2 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),


        child: Column(
          children: [
            Row(
              children: [
                // Tier badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: badgeColor.withOpacity(0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_badgeIcon(), color: badgeColor, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        '${membership.membershipName.toUpperCase()} ${isActive ? "ACTIVE" : ""}',
                        style: TextStyle(
                          color: badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (isActive)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: HunterTheme.success,
                    ),
                  ),
              ],
            ),
            if (membership.hasPremium && countdown != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: HunterTheme.textTertiary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Expires in:',
                    style: TextStyle(
                      color: HunterTheme.textTertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),


                  Text(
                    countdown,
                    style: TextStyle(
                      color: HunterTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
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

    return Semantics(
      label: '${widget.title} plan. ${widget.subtitle}. '
          '${widget.isCurrent ? "This is your current plan." : ""}',
      child: MouseRegion(
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
                color: HunterTheme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isCurrent
                      ? accent.withOpacity(0.9)
                      : HunterTheme.border,
                  width: widget.isCurrent ? 1.6 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(
                        _hovered ? 0.28 : (widget.isCurrent ? 0.22 : 0.12)),
                    blurRadius: _hovered ? 26 : 18,
                    spreadRadius: widget.isCurrent ? 1 : 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black
                        .withOpacity(HunterTheme.isDark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header row ──
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(widget.icon, color: accent, size: 26),
                      ),
                      const SizedBox(width: 14),


                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: HunterTheme.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                                if (widget.isCurrent) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: HunterTheme.success.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: HunterTheme.success.withOpacity(0.5)),
                                    ),
                                    child: Text(
                                      'CURRENT',
                                      style: TextStyle(
                                        color: HunterTheme.success,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: accent,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),


                  // ── Features list ──
                  ...widget.features.map(
                    (feature) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: accent, size: 17),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              feature,
                              style: TextStyle(
                                color: HunterTheme.textSecondary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Progress text (Max card) ──
                  if (widget.progressText != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.progressText!,
                      style: TextStyle(
                        color: HunterTheme.textTertiary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Ad button ──
                  if (widget.adButton != null) ...[
                    const SizedBox(height: 8),
                    widget.adButton!,
                  ],
                ],
              ),
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
  });

  final _AdButtonState state;
  final String label;
  final String sublabel;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case _AdButtonState.loading:
        return _buildDisabledButton(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: HunterTheme.textFaint,
                  semanticsLabel: 'Loading rewarded ad',
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Loading Rewarded Ad...',
                style: TextStyle(
                  color: HunterTheme.textFaint,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );

      case _AdButtonState.unavailable:
        return Column(
          children: [
            _buildDisabledButton(
              child: Text(
                'Rewarded Ad Unavailable',
                style: TextStyle(
                  color: HunterTheme.textFaint,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),


            const SizedBox(height: 8),
            Text(
              "Rewarded video isn't available right now. Please try again later.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: HunterTheme.textTertiary,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        );

      case _AdButtonState.ready:
        return Semantics(
          button: true,
          label: '$label $sublabel',
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor,
                    accentColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '\u{1F3A5}',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),


                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sublabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  Widget _buildDisabledButton({required Widget child}) {
    return Semantics(
      button: true,
      enabled: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: HunterTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: HunterTheme.border),
        ),
        child: Center(child: child),
      ),
    );
  }
}

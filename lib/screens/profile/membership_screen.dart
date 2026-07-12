import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Premium "Hunter Membership" screen.
///
/// UI ONLY: displays the hunter's current membership tier (read from
/// [MembershipService]) and the three available tiers (Basic / Pro / Max)
/// with their feature lists. No payment provider is wired up yet — the Pro
/// and Max upgrade buttons intentionally show "Coming Soon" so the checkout
/// flow (Razorpay) can be plugged in later without touching this screen's
/// layout.
///
/// This screen never writes membership data and never compares raw
/// membership strings directly — it only reads from [MembershipService].
class MembershipScreen extends StatefulWidget {
  const MembershipScreen({super.key});

  @override
  State<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends State<MembershipScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;

  /// Staggered fade + slide-up animations, one per plan card, driven by a
  /// single [_entranceController] so the cards animate into view in
  /// sequence when the screen first opens.
  late final List<Animation<double>> _cardFade;
  late final List<Animation<Offset>> _cardSlide;

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

    // Ensure membership is available before the first frame paints; this is
    // a no-op if it was already loaded elsewhere in the app (e.g. on login).
    MembershipService.instance.loadMembership().whenComplete(() {
      if (mounted) setState(() {});
    });

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Shows a lightweight "Coming Soon" notice for the not-yet-implemented
  /// Razorpay-powered upgrade flow.
  void _showComingSoon(BuildContext context, String planName) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: HunterTheme.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: HunterTheme.primary.withOpacity(0.35)),
        ),
        content: Row(
          children: [
            Icon(Icons.hourglass_top_rounded,
                color: HunterTheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$planName upgrades are coming soon!',
                style: TextStyle(
                  color: HunterTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                      _AnimatedPlanCard(
                        fade: _cardFade[0],
                        slide: _cardSlide[0],
                        child: _PlanCard(
                          tier: MembershipTier.basic,
                          icon: Icons.shield_outlined,
                          accentColor: HunterTheme.textSecondary,
                          title: 'Basic',
                          price: 'FREE',
                          isCurrent: membership.isBasic,
                          features: const [
                            'Current Hunter Experience',
                            'Limited AI',
                            'Default Badge',
                            'Default Frame',
                            'Banner Ads',
                            'Rewarded Ads',
                          ],
                          buttonLabel:
                          membership.isBasic ? 'Current Plan' : 'Free',
                          buttonEnabled: false,
                          onPressed: null,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AnimatedPlanCard(
                        fade: _cardFade[1],
                        slide: _cardSlide[1],
                        child: _PlanCard(
                          tier: MembershipTier.pro,
                          icon: Icons.workspace_premium_rounded,
                          accentColor: HunterTheme.gold,
                          title: 'Pro',
                          price: '₹49/month',
                          isCurrent: membership.isPro,
                          features: const [
                            'Unlimited Profile Changes',
                            'Gold Badge',
                            'Gold Leaderboard Frame',
                            'Gold Name Glow',
                            'Premium Duel Frame',
                            'Higher AI Limits',
                            'Visible To Everyone',
                          ],
                          buttonLabel: membership.isPro
                              ? 'Current Plan'
                              : 'Coming Soon',
                          buttonEnabled: !membership.isPro,
                          onPressed: membership.isPro
                              ? null
                              : () => _showComingSoon(context, 'Pro'),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _AnimatedPlanCard(
                        fade: _cardFade[2],
                        slide: _cardSlide[2],
                        child: _PlanCard(
                          tier: MembershipTier.max,
                          icon: Icons.auto_awesome_rounded,
                          accentColor: HunterTheme.purple,
                          title: 'Max',
                          price: '₹99/month',
                          isCurrent: membership.isMax,
                          features: const [
                            'Everything in Pro',
                            'Remove All Ads',
                            'Unlimited AI',
                            'Animated Leaderboard Frame',
                            'Animated Name Glow',
                            'Animated Avatar Border',
                            'Premium Themes',
                            'Advanced Statistics',
                            'Visible To Everyone',
                          ],
                          buttonLabel: membership.isMax
                              ? 'Current Plan'
                              : 'Coming Soon',
                          buttonEnabled: !membership.isMax,
                          onPressed: membership.isMax
                              ? null
                              : () => _showComingSoon(context, 'Max'),
                        ),
                      ),
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

/// Screen header: "⚔ HUNTER MEMBERSHIP" title with a supporting subtitle.
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
            '⚔ HUNTER MEMBERSHIP',
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
          'Support Hunter Ascend and unlock exclusive cosmetics and premium features.',
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

/// Displays the hunter's current membership tier with a colored badge.
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

  @override
  Widget build(BuildContext context) {
    final badgeColor = _badgeColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HunterTheme.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(HunterTheme.isDark ? 0.35 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'Current Plan',
            style: TextStyle(
              color: HunterTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
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
                  membership.membershipName,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a plan card with the staggered fade + slide-up entrance animation.
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

/// A single premium membership plan card (Basic, Pro, or Max).
///
/// Handles its own press/hover scale animation for a tactile, premium feel
/// — no external animation packages are used.
class _PlanCard extends StatefulWidget {
  const _PlanCard({
    required this.tier,
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.price,
    required this.isCurrent,
    required this.features,
    required this.buttonLabel,
    required this.buttonEnabled,
    required this.onPressed,
  });

  final MembershipTier tier;
  final IconData icon;
  final Color accentColor;
  final String title;
  final String price;
  final bool isCurrent;
  final List<String> features;
  final String buttonLabel;
  final bool buttonEnabled;
  final VoidCallback? onPressed;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
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
                  color:
                  Colors.black.withOpacity(HunterTheme.isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                                    color: accent.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: accent.withOpacity(0.6)),
                                  ),
                                  child: Text(
                                    'CURRENT',
                                    style: TextStyle(
                                      color: accent,
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
                            widget.price,
                            style: TextStyle(
                              color: accent,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: widget.buttonEnabled ? widget.onPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isCurrent
                          ? accent.withOpacity(0.15)
                          : (widget.buttonEnabled
                          ? accent
                          : HunterTheme.surface),
                      foregroundColor: widget.isCurrent
                          ? accent
                          : (widget.buttonEnabled
                          ? Colors.white
                          : HunterTheme.textFaint),
                      disabledBackgroundColor: widget.isCurrent
                          ? accent.withOpacity(0.15)
                          : HunterTheme.surface,
                      disabledForegroundColor:
                      widget.isCurrent ? accent : HunterTheme.textFaint,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: widget.isCurrent
                              ? accent.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Text(
                      widget.buttonLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
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

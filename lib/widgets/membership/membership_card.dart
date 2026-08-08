import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Membership-aware card container.
///
/// Reads [MembershipTheme.current] at build time, so the card automatically
/// matches the effective tier:
///
/// * Basic → the stock card (cardColor + neutral border + soft shadow),
///   pixel-identical to the pre-existing design.
/// * Pro   → gold-tinted sheen, gold border, warm glow.
/// * Max   → purple-tinted sheen, purple border, stronger neon glow.
///
/// The parent screen is responsible for rebuilding on tier change (every
/// screen already merges [MembershipTheme.tierNotifier] into its
/// ListenableBuilder), so this widget holds no listeners of its own.
class MembershipCard extends StatelessWidget {
  const MembershipCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.radius,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// Optional radius override; defaults to the tier's [cardRadius].
  final double? radius;

  /// Optional border color override (e.g. a semantic accent for a focused
  /// card). Defaults to the tier border treatment.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    final isPremium = tokens.isPremium;
    final r = radius ?? tokens.cardRadius;

    final decoration = BoxDecoration(
      gradient: isPremium
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                tokens.accent
                    .withOpacity(MembershipTheme.isMax ? 0.10 : 0.07),
                HunterTheme.cardColor,
              ],
            )
          : null,
      color: isPremium ? null : HunterTheme.cardColor,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(
        color: borderColor ??
            (isPremium
                ? tokens.accent.withOpacity(0.35)
                : HunterTheme.border),
        width: isPremium ? tokens.cardBorderWidth : 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(HunterTheme.isDark ? 0.30 : 0.05),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        if (isPremium)
          BoxShadow(
            color: tokens.accent.withOpacity(0.16 * tokens.glowStrength),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 6),
          ),
      ],
    );

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: card);
  }
}

/// Flat membership-aware panel — lighter than a [MembershipCard] (no shadow).
///
/// Use for section backgrounds, list containers and inline panels:
///
/// * Basic → plain cardColor panel with a neutral border (stock look).
/// * Pro   → faint gold sheen + gold hairline.
/// * Max   → faint purple sheen + purple hairline.
class MembershipSurface extends StatelessWidget {
  const MembershipSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    final isPremium = tokens.isPremium;
    final r = radius ?? tokens.cardRadius;

    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        gradient: isPremium
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tokens.accent.withOpacity(0.05),
                  HunterTheme.cardColor,
                ],
              )
            : null,
        color: isPremium ? null : HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(
          color: isPremium
              ? tokens.accent.withOpacity(0.25)
              : HunterTheme.border,
          width: isPremium ? tokens.cardBorderWidth : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Small tier badge chip ("PRO MEMBER" / "MAX • ELITE HUNTER"), matching the
/// badge language of the Pro/Max dashboards. For Basic it renders nothing.
class MembershipBadgeChip extends StatelessWidget {
  const MembershipBadgeChip({super.key, this.compact = false});

  /// Renders a smaller chip for tight layouts (cards, list rows).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = MembershipTheme.current;
    if (!tokens.isPremium) return const SizedBox.shrink();

    final isMax = tokens.tier == MembershipTier.max;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        gradient: isMax
            ? LinearGradient(colors: [
                tokens.accent,
                Colors.pinkAccent.withOpacity(0.7),
              ])
            : null,
        color: isMax ? null : Colors.white.withOpacity(0.22),
        borderRadius: BorderRadius.circular(8),
        border: isMax
            ? null
            : Border.all(color: Colors.white.withOpacity(0.5)),
      ),
      child: Text(
        isMax ? 'MAX \u2022 ELITE HUNTER' : 'PRO MEMBER',
        style: TextStyle(
          // On Pro the chip sits on gold heroes (white text); on flat light
          // surfaces use the accent instead for legibility.
          color: Colors.white,
          fontSize: compact ? 8.5 : 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

// Re-export so membership widget files only need the membership_theme import.
export 'package:hunter_ascend/services/membership_service.dart'
    show MembershipTier;

/// Membership-aware design tokens.
///
/// A pure data object describing every visual knob the membership tier
/// controls. Instances are immutable and cheap to compare. Screens never
/// construct these directly — they ask [MembershipTheme.current] (or the
/// [MembershipTheme.of] convenience getter) and receive the tokens that
/// match the *effective* membership tier resolved by [MembershipService].
///
/// Basic  → the stock design, token-for-token identical to the pre-existing
///          UI (so Basic users see zero change).
/// Pro    → the Pro dashboard visual language: gold accents, premium
///          gradients, warm glow.
/// Max    → the Max dashboard visual language: purple/luxury accents, rich
///          gradients, stronger neon glow.
@immutable
class MembershipThemeTokens {
  const MembershipThemeTokens({
    required this.tier,
    required this.accent,
    required this.accentAlt,
    required this.gradient,
    required this.heroGradient,
    required this.glowStrength,
    required this.cardRadius,
    required this.cardBorderWidth,
    required this.label,
  });

  /// The tier these tokens describe.
  final MembershipTier tier;

  /// Primary membership accent (gold for Pro, purple for Max, app primary
  /// for Basic).
  final Color accent;

  /// Secondary accent used to finish gradients (brighter sibling of
  /// [accent]).
  final Color accentAlt;

  /// Two-stop gradient for buttons, active indicators and accent chips.
  final List<Color> gradient;

  /// Multi-stop immersive gradient for app bars, hero surfaces and large
  /// premium panels.
  final List<Color> heroGradient;

  /// Relative glow/shadow intensity (0 = none, 1 = Pro, >1 = Max). Multiply
  /// blur/opacity by this so Basic stays flat and Max glows hardest.
  final double glowStrength;

  /// Corner radius used by premium cards/surfaces.
  final double cardRadius;

  /// Border width used by premium cards/surfaces (0 = borderless Basic).
  final double cardBorderWidth;

  /// Short human-readable tier label ("BASIC" / "PRO" / "MAX").
  final String label;

  bool get isPremium => tier != MembershipTier.basic;
}

/// Single source of truth for resolving the current membership into design
/// tokens.
///
/// ## Usage
/// ```dart
/// final theme = MembershipTheme.current; // tokens for the live tier
/// final accent = theme.accent;
/// ```
///
/// Screens that already rebuild on [MembershipService.instance.tierNotifier]
/// (most do, via their ListenableBuilder) automatically re-read fresh tokens
/// the instant the tier changes — no restart required and no extra listeners
/// per screen.
class MembershipTheme {
  MembershipTheme._();

  /// The effective membership tier right now (already accounts for expiry
  /// and Basic-Mode override, because [MembershipService.tierNotifier] holds
  /// the *effective* tier).
  static MembershipTier get tier =>
      MembershipService.instance.tierNotifier.value;

  static bool get isBasic => tier == MembershipTier.basic;
  static bool get isPro => tier == MembershipTier.pro;
  static bool get isMax => tier == MembershipTier.max;
  static bool get isPremium => !isBasic;

  /// The [ValueNotifier] driving tier changes. Add it to a screen's
  /// ListenableBuilder.merge(...) to rebuild when membership changes.
  static ValueNotifier<MembershipTier> get tierNotifier =>
      MembershipService.instance.tierNotifier;

  /// Tokens for the current tier.
  static MembershipThemeTokens get current => forTier(tier);

  /// Alias so screens read naturally: `MembershipTheme.of(context)`.
  // ignore: avoid_unused_constructor_parameters
  static MembershipThemeTokens of(BuildContext context) => current;

  /// Returns the token set for an explicit [tier] (used to preview another
  /// tier, e.g. on the Membership upsell screen).
  ///
  /// Tokens are constructed on every call so their colors always reflect the
  /// *current* light/dark mode ([HunterTheme] colors are mode-dynamic).
  /// Construction is a handful of small objects — negligible per build.
  static MembershipThemeTokens forTier(MembershipTier tier) {
    switch (tier) {
      case MembershipTier.basic:
        // Identical to the existing stock design — Basic users see no change.
        return MembershipThemeTokens(
          tier: MembershipTier.basic,
          accent: HunterTheme.primary,
          accentAlt: HunterTheme.secondary,
          gradient: HunterTheme.primaryGradient,
          heroGradient: [HunterTheme.background, HunterTheme.surface],
          glowStrength: 0.0,
          cardRadius: 16,
          cardBorderWidth: 0,
          label: 'BASIC',
        );
      case MembershipTier.pro:
        // Professional Pro: muted gold accents, restrained glow, dark surfaces.
        return MembershipThemeTokens(
          tier: MembershipTier.pro,
          accent: HunterTheme.gold,
          accentAlt: HunterTheme.goldBright,
          gradient: const [HunterTheme.gold, HunterTheme.goldBright],
          // Professional dark hero with subtle gold accent (not large gold block)
          heroGradient: [
            const Color(0xFF1A1D23).withOpacity(0.95), // Deep charcoal
            HunterTheme.gold.withOpacity(0.15),
          ],
          glowStrength: 0.6, // Reduced from 1.0 for subtlety
          cardRadius: 20,
          cardBorderWidth: 1.0, // Thinner borders
          label: 'PRO',
        );
      case MembershipTier.max:
        // The Max dashboard visual language: purple/luxury + neon glow.
        return MembershipThemeTokens(
          tier: MembershipTier.max,
          accent: HunterTheme.purple,
          accentAlt: HunterTheme.purpleLight,
          gradient: const [HunterTheme.purple, HunterTheme.purpleLight],
          heroGradient: const [Color(0xFF1A0B2E), Color(0xFF9B59B6)],
          glowStrength: 1.4,
          cardRadius: 24,
          cardBorderWidth: 1.4,
          label: 'MAX',
        );
    }
  }
}

/// Convenience extension so any [BuildContext] can ask for the current
/// membership tokens: `context.membershipTheme`.
extension MembershipThemeX on BuildContext {
  MembershipThemeTokens get membershipTheme => MembershipTheme.of(this);
  MembershipTier get currentMembership => MembershipTheme.tier;
  bool get isPremiumMember => MembershipTheme.isPremium;
}

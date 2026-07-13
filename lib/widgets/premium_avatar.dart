import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Displays a hunter's avatar with a membership-tier-appropriate border and
/// glow.
///
/// Accepts a plain [membership] tier string rather than reading
/// [MembershipService] directly, because this widget is used to display
/// OTHER hunters throughout the app (leaderboard, compare, public profile,
/// etc.) — not just the current user. The static Pro treatment is driven by
/// [MembershipFeatures.goldFrame] / [MembershipFeatures.goldGlow] for the
/// parsed tier, so that rule lives in exactly one place.
///
/// Max's purple/gold treatment is intentionally NOT driven by
/// [MembershipFeatures.animatedFrame] / [MembershipFeatures.animatedGlow] —
/// those flags are reserved for a future animated treatment that is not yet
/// implemented. Until that's built, Max keeps its existing static
/// purple/gold look below (unchanged from before this refactor).
class PremiumAvatar extends StatelessWidget {
  final String membership;
  final double radius;
  final ImageProvider? image;
  final Widget? child;

  const PremiumAvatar({
    super.key,
    required this.membership,
    required this.radius,
    this.image,
    this.child,
  });

  /// Parses the raw tier string into a [MembershipTier], mirroring
  /// [MembershipService]'s own parsing so unrecognized/empty values safely
  /// fall back to Basic. Kept local (rather than reusing a shared parser)
  /// so this widget stays fully decoupled from [MembershipService].
  MembershipTier _parseTier(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'pro':
        return MembershipTier.pro;
      case 'max':
        return MembershipTier.max;
      default:
        return MembershipTier.basic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tier = _parseTier(membership);

    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadows = [];

    if (tier == MembershipTier.max) {
      // Max's static placeholder look. This will eventually be replaced by
      // an animated treatment gated on MembershipFeatures.animatedFrame /
      // animatedGlow — intentionally not implemented yet, so the existing
      // static purple/gold visuals are preserved as-is here.
      borderColor = HunterTheme.purple;
      borderWidth = 3;
      shadows = [
        BoxShadow(
          color: HunterTheme.purple.withOpacity(0.5),
          blurRadius: 12,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: HunterTheme.gold.withOpacity(0.35),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ];
    } else {
      // Basic/Pro: driven by the real MembershipFeatures config instead of
      // a duplicated hardcoded switch, so the Pro gold treatment stays in
      // sync with MembershipFeatures.pro if that config ever changes.
      final features = MembershipFeatures.forTier(tier);
      if (features.goldFrame) {
        borderColor = HunterTheme.gold;
        borderWidth = 2.5;
        shadows = features.goldGlow
            ? [
          BoxShadow(
            color: HunterTheme.gold.withOpacity(0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ]
            : [];
      } else {
        borderColor = HunterTheme.border;
        borderWidth = 1.2;
      }
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: borderWidth,
        ),
        boxShadow: shadows,
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: HunterTheme.surface,
        backgroundImage: image,
        child: image == null ? child : null,
      ),
    );
  }
}
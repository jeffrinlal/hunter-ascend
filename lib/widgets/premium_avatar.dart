import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Displays a hunter's avatar with a membership-tier-appropriate border and
/// glow.
///
/// Accepts a plain [membership] tier string because this widget is used to
/// display OTHER hunters throughout the app (leaderboard, compare, public
/// profile, etc.) — not just the current user. All feature decisions
/// (border color, glow, sizing) are driven exclusively by
/// [MembershipFeatures] getters so that tier rules live in exactly one place.
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

  @override
  Widget build(BuildContext context) {
    // Resolve the tier and its feature set through the canonical enum parser
    // and the feature configuration model — no raw string comparisons here.
    final tier = MembershipTier.fromString(membership);
    final features = MembershipFeatures.forTier(tier);

    Color borderColor;
    double borderWidth;
    List<BoxShadow> shadows = [];

    if (features.animatedFrame) {
      // Max tier: static purple/gold placeholder look. The animatedFrame and
      // animatedGlow feature flags gate this treatment. When actual animation
      // is implemented in the future it will replace this static version, but
      // the same feature getters will continue to gate it.
      borderColor = HunterTheme.purple;
      borderWidth = 3;
      shadows = [
        BoxShadow(
          color: HunterTheme.purple.withOpacity(0.5),
          blurRadius: 12,
          spreadRadius: 2,
        ),
        if (features.animatedGlow)
          BoxShadow(
            color: HunterTheme.gold.withOpacity(0.35),
            blurRadius: 18,
            spreadRadius: 1,
          ),
      ];
    } else if (features.goldFrame) {
      // Pro tier: gold border with optional gold glow.
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
      // Basic tier: plain border, no glow.
      borderColor = HunterTheme.border;
      borderWidth = 1.2;
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

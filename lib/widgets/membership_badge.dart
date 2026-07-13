import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Displays a compact membership badge (🛡 PRO / 👑 MAX) next to a hunter's
/// name. Renders nothing for Basic.
///
/// Accepts a plain [membership] tier string because this widget is used to
/// display OTHER hunters throughout the app (leaderboard, compare, public
/// profile, etc.) — not just the current user. All feature decisions
/// (visibility, styling) are driven exclusively by [MembershipFeatures]
/// getters so that tier rules live in exactly one place.
class MembershipBadge extends StatelessWidget {
  final String membership;
  final double fontSize;

  const MembershipBadge({
    super.key,
    required this.membership,
    this.fontSize = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve the tier and its feature set through the canonical enum parser
    // and the feature configuration model — no raw string comparisons here.
    final tier = MembershipTier.fromString(membership);
    final features = MembershipFeatures.forTier(tier);

    // Only show the badge if the tier unlocks the gold badge cosmetic.
    if (!features.goldBadge) {
      return const SizedBox.shrink();
    }

    // Use the animatedFrame feature getter to distinguish Max-tier styling
    // from Pro-tier styling — animatedFrame is true exclusively for Max.
    final bool useMaxStyle = features.animatedFrame;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        gradient: useMaxStyle
            ? LinearGradient(
          colors: [
            HunterTheme.purple,
            HunterTheme.gold,
          ],
        )
            : LinearGradient(
          colors: [
            HunterTheme.gold,
            HunterTheme.primary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            useMaxStyle ? "👑" : "🛡",
            style: TextStyle(fontSize: fontSize + 2),
          ),
          const SizedBox(width: 4),
          Text(
            useMaxStyle ? 'MAX' : 'PRO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
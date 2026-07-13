import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

/// Displays a compact membership badge (🛡 PRO / 👑 MAX) next to a hunter's
/// name. Renders nothing for Basic.
///
/// Accepts a plain [membership] tier string rather than reading
/// [MembershipService] directly, because this widget is used to display
/// OTHER hunters throughout the app (leaderboard, compare, public profile,
/// etc.) — not just the current user. Whether a badge renders at all is
/// driven by [MembershipFeatures.goldBadge] for the parsed tier, so that
/// rule lives in exactly one place instead of being duplicated here.
class MembershipBadge extends StatelessWidget {
  final String membership;
  final double fontSize;

  const MembershipBadge({
    super.key,
    required this.membership,
    this.fontSize = 10,
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
    final features = MembershipFeatures.forTier(tier);

    if (!features.goldBadge) {
      return const SizedBox.shrink();
    }

    final bool isMax = tier == MembershipTier.max;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        gradient: isMax
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
            isMax ? "👑" : "🛡",
            style: TextStyle(fontSize: fontSize + 2),
          ),
          const SizedBox(width: 4),
          Text(
            isMax ? 'MAX' : 'PRO',
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
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/membership_service.dart';

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
    final tier = membership.toLowerCase();

    if (tier == 'basic' || tier.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isMax = tier == 'max';

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
            tier.toUpperCase(),
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
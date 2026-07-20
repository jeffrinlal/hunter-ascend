import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Animated circular XP progress ring used in Pro and Max dashboards.
///
/// Purely presentational — takes [xp] (0-500) and [level] and renders
/// a smooth circular progress indicator with optional glow effect.
class AnimatedXpRing extends StatelessWidget {
  final int xp;
  final int level;
  final double size;
  final bool showGlow;

  /// Whether to render the center label (LV / level / xp).
  ///
  /// Set to `false` when the ring is used purely as a decorative progress
  /// arc around an avatar — otherwise the label renders *behind* the avatar
  /// (hidden, and peeking out at the edges). The Pro and Max heroes show the
  /// level/XP as separate text below the avatar, so they pass `false`.
  final bool showLabel;
  final Color? accentColor;

  const AnimatedXpRing({
    super.key,
    required this.xp,
    required this.level,
    this.size = 120,
    this.showGlow = false,
    this.showLabel = true,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? HunterTheme.primary;
    final progress = (xp / 500).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow (Max only)
          if (showGlow)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.3),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),

          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: showGlow ? 6 : 5,
              color: HunterTheme.border,
            ),
          ),

          // Progress ring
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: progress),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: showGlow ? 6 : 5,
                strokeCap: StrokeCap.round,
                color: accent,
              ),
            ),
          ),

          // Center content (omitted when an avatar is overlaid on the ring).
          if (showLabel)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'LV',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '$level',
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: size * 0.28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '$xp/500',
                  style: TextStyle(
                    color: HunterTheme.textTertiary,
                    fontSize: size * 0.09,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

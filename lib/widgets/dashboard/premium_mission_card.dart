import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Pro dashboard's redesigned "Today's Mission" (steps) card.
///
/// Purely presentational — takes the same [steps] value as [StepsCard] and
/// renders it against the same fixed 10,000-step goal, but with a circular
/// radial gauge, asymmetric rounded shape, and gold accent instead of the
/// Basic dashboard's linear progress bar. No Firestore/business logic here.
class PremiumMissionCard extends StatelessWidget {
  final int steps;

  const PremiumMissionCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final progress = (steps / 10000).clamp(0.0, 1.0);
    final percent = (progress * 100).toInt();
    final accent = HunterTheme.gold;
    final complete = steps >= 10000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(12),
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(30),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accent.withOpacity(0.12), HunterTheme.cardColor],
        ),
        border: Border.all(color: accent.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: accent.withOpacity(0.12), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: CircularProgressIndicator(value: 1, strokeWidth: 7, color: HunterTheme.border),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => SizedBox(
                    width: 74,
                    height: 74,
                    child: CircularProgressIndicator(
                      value: value,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      color: accent,
                    ),
                  ),
                ),
                Text('$percent%', style: TextStyle(color: HunterTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.directions_walk_rounded, color: accent, size: 16),
                  const SizedBox(width: 6),
                  Text('PREMIUM MISSION', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
                ]),
                const SizedBox(height: 6),
                Text('$steps steps', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  complete ? '🏆 Goal Completed! +25 XP' : 'Goal: 10,000 steps',
                  style: TextStyle(color: complete ? Colors.amber : HunterTheme.textTertiary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Today's step-goal progress card.
///
/// Purely presentational widget extracted from DashboardScreen. It only
/// renders the provided [steps] against the fixed 10,000-step goal — it holds
/// no state and performs no Firestore, timer, ad, or navigation work.
class StepsCard extends StatelessWidget {
  final int steps;

  const StepsCard({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final percent = ((steps / 10000) * 100).clamp(0, 100).toInt();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HunterTheme.border, width: 1.5),
        boxShadow: [BoxShadow(color: HunterTheme.primary.withOpacity(0.1), blurRadius: 16)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: HunterTheme.border, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.directions_walk, color: HunterTheme.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Text("TODAY'S MISSION", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, letterSpacing: 1)),
            const Spacer(),
            Text("$percent%", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13)),
          ]),
          const SizedBox(height: 10),
          Text("10,000 STEPS", style: TextStyle(color: HunterTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (steps / 10000).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: HunterTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(HunterTheme.primary),
            ),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("$steps / 10,000", style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              steps >= 10000 ? "🏆 Goal Completed! +25 XP" : "🎯 Keep going!",
              style: TextStyle(color: steps >= 10000 ? Colors.amber : HunterTheme.textTertiary, fontSize: 12),
            ),
          ]),
        ],
      ),
    );
  }
}

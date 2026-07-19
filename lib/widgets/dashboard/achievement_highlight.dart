import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// Max-exclusive horizontal row of achievement highlight cards.
///
/// Purely presentational — reads only fields already present on [HunterData]
/// (`duelWins`, `questsDone`, `streak`), which the parent screen already
/// streams from Firestore via `HunterRepository`. Introduces no new reads.
class AchievementHighlightRow extends StatelessWidget {
  final int duelWins;
  final int questsDone;
  final int streak;

  const AchievementHighlightRow({
    super.key,
    required this.duelWins,
    required this.questsDone,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Color)>[
      (Icons.emoji_events_rounded, '$duelWins', 'Duel Wins', HunterTheme.gold),
      (Icons.checklist_rounded, '$questsDone', 'Quests Done', HunterTheme.purple),
      (Icons.local_fire_department_rounded, '$streak', 'Day Streak', Colors.orange),
    ];

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowHeight = (90 * textScale).clamp(90.0, 120.0);

    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final (icon, value, label, color) = items[i];
          return Container(
            width: 112,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withOpacity(0.18), HunterTheme.cardColor],
              ),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const Spacer(),
                Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

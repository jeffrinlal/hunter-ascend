import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Horizontal, scrollable row of pill-shaped stat chips.
///
/// Purely presentational — reuses the same [DashboardStat] data model as
/// [DashboardStatsGrid] but renders it as a horizontal strip of "floating"
/// pills instead of a wrapped grid. Used by the Pro dashboard (gold/blue
/// variant) and Max dashboard (neon [elite] variant) to give stats a
/// structurally different presentation than the Basic screen, and different
/// from each other via the [elite] flag.
class DashboardStatChipRow extends StatelessWidget {
  final List<DashboardStat> stats;
  final bool elite;

  const DashboardStatChipRow({super.key, required this.stats, this.elite = false});

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final rowHeight = (96 * textScale).clamp(96.0, 130.0);
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: stats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _StatChip(stat: stats[i], elite: elite),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final DashboardStat stat;
  final bool elite;
  const _StatChip({required this.stat, required this.elite});

  @override
  Widget build(BuildContext context) {
    final accent = stat.color ?? HunterTheme.primary;
    return Container(
      width: 118,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(elite ? 18 : 24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: elite
              ? [accent.withOpacity(0.22), HunterTheme.cardColor]
              : [accent.withOpacity(0.16), HunterTheme.cardColor],
        ),
        border: Border.all(color: accent.withOpacity(elite ? 0.55 : 0.35), width: elite ? 1.4 : 1.2),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(elite ? 0.28 : 0.12),
            blurRadius: elite ? 16 : 10,
            spreadRadius: elite ? 1 : 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: accent.withOpacity(0.18), shape: BoxShape.circle),
            child: Icon(stat.icon, color: accent, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

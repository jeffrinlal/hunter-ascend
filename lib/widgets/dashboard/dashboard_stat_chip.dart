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
///
/// ## Layout / overflow safety
/// The row is **content-driven**: it uses a horizontal [SingleChildScrollView]
/// + [IntrinsicHeight] so each chip determines its own height and all chips
/// share the tallest one. It deliberately does NOT wrap the chips in a
/// fixed-height [SizedBox] + horizontal [ListView], because that forces a
/// tight height onto each chip and squeezes its inner [Column] — which
/// overflowed by a few pixels whenever the font's line-height or the system
/// text scale pushed the content just past the computed height.
class DashboardStatChipRow extends StatelessWidget {
  final List<DashboardStat> stats;
  final bool elite;

  const DashboardStatChipRow({super.key, required this.stats, this.elite = false});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              _StatChip(stat: stats[i], elite: elite),
            ],
          ],
        ),
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
        // Professional: dark surface with subtle colored border
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(elite ? 0.40 : 0.25), width: elite ? 1.2 : 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: accent.withOpacity(elite ? 0.12 : 0.08),
            blurRadius: elite ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // mainAxisSize.min so the chip hugs its content; IntrinsicHeight in the
      // parent then makes every chip match the tallest one.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: accent.withOpacity(0.3), width: 1),
            ),
            child: Icon(stat.icon, color: accent, size: 16),
          ),
          const SizedBox(height: 8),
          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

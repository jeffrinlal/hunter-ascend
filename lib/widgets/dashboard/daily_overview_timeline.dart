import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Vertical timeline-style presentation of daily stats for the Max dashboard.
///
/// Purely presentational — reuses the same [DashboardStat] data model as
/// [DashboardStatsGrid] / [DashboardStatChipRow], but renders each stat as a
/// node on a connected vertical timeline instead of a grid or horizontal
/// strip, giving Max's "Daily Overview" section a structurally distinct look
/// from Pro's floating chips and Basic's plain cards.
class DailyOverviewTimeline extends StatelessWidget {
  final List<DashboardStat> stats;

  const DailyOverviewTimeline({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stats.length, (i) {
        final stat = stats[i];
        final accent = stat.color ?? HunterTheme.purple;
        final isLast = i == stats.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withOpacity(0.15),
                      border: Border.all(color: accent, width: 1.4),
                      boxShadow: [BoxShadow(color: accent.withOpacity(0.3), blurRadius: 8)],
                    ),
                    child: Icon(stat.icon, color: accent, size: 16),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(width: 2, color: accent.withOpacity(0.2)),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(stat.label, style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(stat.value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

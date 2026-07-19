import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';

/// A single stat item for the dashboard grid.
class DashboardStat {
  const DashboardStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}

/// Grid of dashboard statistics (used in Pro/Max dashboards).
class DashboardStatsGrid extends StatelessWidget {
  final List<DashboardStat> stats;
  final int crossAxisCount;

  const DashboardStatsGrid({
    super.key,
    required this.stats,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: stats.map((stat) => _StatCard(stat: stat, crossAxisCount: crossAxisCount)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  final DashboardStat stat;
  final int crossAxisCount;

  const _StatCard({required this.stat, required this.crossAxisCount});

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 32 - (12 * (crossAxisCount - 1))) / crossAxisCount;
    final accent = stat.color ?? HunterTheme.primary;

    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: accent, size: 20),
          const SizedBox(height: 10),
          Text(
            stat.value,
            style: TextStyle(
              color: HunterTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            style: TextStyle(
              color: HunterTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

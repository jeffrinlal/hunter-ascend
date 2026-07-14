// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../utils/report_palette.dart';
import 'report_card.dart';

/// Wraps a report section in a subtle staggered fade + slight upward slide.
///
/// The slide is intentionally small (10px) and the curve is a plain ease-out —
/// elegant, not flashy.
class ReportSection extends StatelessWidget {
  const ReportSection({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, 10 * (1 - animation.value)),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

/// Premium hero section shown before all statistics, styled like the header of
/// an official System window: title, subtitle, generation date, and a local
/// (backend-free) Report ID for visual polish.
class ReportHero extends StatelessWidget {
  const ReportHero({
    super.key,
    required this.generatedDate,
    required this.reportId,
  });

  final String generatedDate;
  final String reportId;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hexagon_outlined,
                  color: ReportPalette.accent.withOpacity(0.9), size: 20),
              const SizedBox(width: 10),
              const Text(
                'HUNTER REPORT',
                style: TextStyle(
                  color: ReportPalette.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'SYSTEM REPORT',
            style: TextStyle(
              color: ReportPalette.accentBright,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 16),
          const HairLine(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metaBlock(
                  icon: Icons.event_available_outlined,
                  label: 'GENERATED',
                  value: generatedDate,
                ),
              ),
              Container(
                width: 1,
                height: 34,
                color: ReportPalette.accent.withOpacity(0.15),
              ),
              Expanded(
                child: _metaBlock(
                  icon: Icons.tag_rounded,
                  label: 'REPORT ID',
                  value: reportId,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaBlock({
    required IconData icon,
    required String label,
    required String value,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment:
              alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Icon(icon, color: ReportPalette.textTertiary, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: ReportPalette.textTertiary,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: ReportPalette.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Segmented 7 / 30-day range toggle. Both options stay within the 30-day cap.
class RangeToggle extends StatelessWidget {
  const RangeToggle({
    super.key,
    required this.rangeDays,
    required this.onChanged,
  });

  final int rangeDays;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: ReportPalette.accent.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill('7 Days', 7),
            _pill('30 Days', 30),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, int days) {
    final selected = rangeDays == days;
    return GestureDetector(
      onTap: () => onChanged(days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ReportPalette.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [BoxShadow(color: ReportPalette.accent.withOpacity(0.4), blurRadius: 12)]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : ReportPalette.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

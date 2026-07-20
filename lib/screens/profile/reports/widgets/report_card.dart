// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

import '../utils/report_format.dart';
import '../utils/report_palette.dart';
import 'count_up.dart';

// NOTE: The widgets below intentionally use NON-const constructors. Their
// build methods read theme-aware [ReportPalette] getters, so they must be
// rebuilt when the app theme toggles. Non-const constructors guarantee fresh
// instances on each parent rebuild (and prevent accidental `const` caching of
// stale colours).

/// Soft, blurred ambient orbs painted behind the content so the glass cards
/// have something to blur. Subtler in light mode (elegant), stronger in dark
/// (blue glow). Purely decorative and non-interactive.
class AmbientGlow extends StatelessWidget {
  AmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = ReportPalette.isDark;
    final o1 = dark ? 0.16 : 0.06;
    final o2 = dark ? 0.12 : 0.05;
    final o3 = dark ? 0.10 : 0.045;
    // Static decorative layer — repaint-isolated so it is cached and never
    // repainted while the report list scrolls over it.
    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                  top: -60,
                  left: -40,
                  child: _orb(220, ReportPalette.accent.withOpacity(o1))),
              Positioned(
                  top: 280,
                  right: -70,
                  child: _orb(240, ReportPalette.gold.withOpacity(o2))),
              Positioned(
                  bottom: -40,
                  left: 20,
                  child: _orb(200, ReportPalette.accent.withOpacity(o3))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      );
}

/// Glassmorphism card: translucent fill + backdrop blur + themed border, with
/// a blue glow in dark mode and an elegant soft shadow in light mode.
class GlassCard extends StatelessWidget {
  GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: previously each card wrapped its content in a real-time
    // BackdropFilter blur. With ~8 cards stacked in a scrolling list, those
    // stacked backdrop blurs were the main source of scroll jank. The frosted
    // look is now achieved with an opaque themed gradient fill (no per-frame
    // blur), and the whole card is repaint-isolated so scrolling stays smooth.
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: ReportPalette.cardShadow,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ReportPalette.glassHi, ReportPalette.glassLo],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ReportPalette.cardBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Section title row: icon + spaced caps title + optional trailing tag.
class SectionHeader extends StatelessWidget {
  SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: ReportPalette.accentBright, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: ReportPalette.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(
              color: ReportPalette.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
      ],
    );
  }
}

/// Thin horizontal divider with a soft blue centre glow.
class HairLine extends StatelessWidget {
  HairLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          ReportPalette.accent.withOpacity(0),
          ReportPalette.accent.withOpacity(0.35),
          ReportPalette.accent.withOpacity(0),
        ]),
      ),
    );
  }
}

/// Italic placeholder line shown when a metric has no data / is unavailable.
class EmptyLine extends StatelessWidget {
  EmptyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: TextStyle(
          color: ReportPalette.textTertiary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Specification for a single statistic cell.
class StatSpec {
  final String label;
  final double value;
  final IconData icon;
  final String? suffix;

  const StatSpec(this.label, this.value, this.icon, {this.suffix});
}

/// A single statistic cell: icon + animated count-up value + label.
class StatCell extends StatelessWidget {
  StatCell({super.key, required this.spec});

  final StatSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: ReportPalette.fillSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ReportPalette.accent.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: ReportPalette.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(spec.icon, color: ReportPalette.accentBright, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountUp(
                  value: spec.value,
                  formatter: (v) => '${fmtInt(v)}${spec.suffix ?? ''}',
                  style: TextStyle(
                    color: ReportPalette.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ReportPalette.textTertiary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

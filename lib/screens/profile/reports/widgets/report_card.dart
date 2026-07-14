// ignore_for_file: deprecated_member_use

import 'dart:ui';

import 'package:flutter/material.dart';

import '../utils/report_format.dart';
import '../utils/report_palette.dart';
import 'count_up.dart';

/// Soft, blurred ambient orbs painted behind the content so the glass cards
/// have something colourful to blur. Purely decorative and non-interactive.
class AmbientGlow extends StatelessWidget {
  const AmbientGlow({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
                top: -60, left: -40, child: _orb(220, ReportPalette.accent.withOpacity(0.18))),
            Positioned(
                top: 280, right: -70, child: _orb(240, ReportPalette.accent.withOpacity(0.12))),
            Positioned(
                bottom: -40,
                left: 20,
                child: _orb(200, const Color(0xFF6E5BFF).withOpacity(0.10))),
          ],
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

/// Glassmorphism card: translucent fill + backdrop blur + blue border + glow.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: ReportPalette.accent.withOpacity(0.10),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: padding ?? const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ReportPalette.glassHi, ReportPalette.glassLo],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: ReportPalette.accent.withOpacity(0.22)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Section title row: icon + spaced caps title + optional trailing tag.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
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
          style: const TextStyle(
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
            style: const TextStyle(
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
  const HairLine({super.key});

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
  const EmptyLine(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        text,
        style: const TextStyle(
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
  const StatCell({super.key, required this.spec});

  final StatSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
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
                  style: const TextStyle(
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
                  style: const TextStyle(
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

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_tone.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Cyber Hunter — tactical HUD / futuristic technology identity.
///
/// ## Architecture
/// Colors come exclusively from [SkinTone] (→ existing `HunterTheme` tokens →
/// active Premium Theme). This file has no literal color values. The skin's
/// identity is carried entirely by structure, shape language, density,
/// typography and motion.
///
/// ## Composition signature (deliberately unlike every other skin)
/// - **Shape language:** hard 6px radii + machined corner-bracket ticks +
///   diagonally clipped panels. No soft/rounded surfaces anywhere.
/// - **Hero:** a telemetry console — blinking `SYS ONLINE` status strip, a
///   *bracket-clipped square* avatar on the LEFT, and data presented as
///   `LABEL … VALUE` telemetry rows (not a name/level stack). XP is a
///   **segmented tick meter** paired with a boxed numeric percentage.
///   A scanline sweeps continuously down the whole panel.
/// - **Quest:** a single horizontal **telemetry strip** — bracketed icon,
///   inline segmented track, and a large right-aligned boxed percentage.
/// - **Stats:** a **2-column grid of compact HUD modules**, each with a top
///   accent rule (not a list, not diamonds, not staggered blocks).
/// - **Water:** a **horizontal segmented tank** with bracket-square
///   increment controls.
/// - **Quick Actions:** two side-by-side **bracketed console tiles** with a
///   `>> ENTER` / `LOCKED` machine caption.
///
/// ## Layout safety
/// Every variable value (name, rank, level, stat values, counts) is bounded
/// by `Expanded`/`Flexible`/`FittedBox` + `ellipsis`. All meters are built
/// from `Expanded` segments so they cannot overflow at any width. The stats
/// grid is composed from explicit 2-up rows wrapped in `IntrinsicHeight`
/// (equal heights, no fixed heights, no aspect-ratio overflow).
class CyberHunterDashboardSections implements DashboardSkinSections {
  const CyberHunterDashboardSections();

  @override
  Widget hero(HeroSectionData data) => _HudHero(data: data);

  @override
  Widget quest(QuestSectionData data) => _HudQuestStrip(data: data);

  @override
  Widget stats(StatsSectionData data) => _HudStatGrid(data: data);

  @override
  Widget water(WaterSectionData data) => _HudTank(data: data);

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _HudConsoleTile(item: data.nutrition)),
        const SizedBox(width: 10),
        Expanded(child: _HudConsoleTile(item: data.map)),
      ],
    );
  }
}

// ── Hero: telemetry console ───────────────────────────────────────────────

class _HudHero extends StatefulWidget {
  const _HudHero({required this.data});
  final HeroSectionData data;

  @override
  State<_HudHero> createState() => _HudHeroState();
}

class _HudHeroState extends State<_HudHero> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hunter = widget.data.hunter;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;
    final progress = (hunter.xp / 500).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: SkinTone.panel,
          border: Border.all(color: SkinTone.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            // Scanline + machined corner brackets. Decorative only, clipped
            // to this panel, never carries or overlaps text.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sweep,
                builder: (context, _) => CustomPaint(
                  painter: _HudFramePainter(
                    t: _sweep.value,
                    accent: SkinTone.accent,
                    accentBright: SkinTone.accentBright,
                    glowStrength: SkinTone.glow,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _statusStrip(blink: _sweep),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bracketAvatar(avatarBytes),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _telemetryRow('OPERATOR', hunter.hunterName),
                            const SizedBox(height: 7),
                            _telemetryRow('CLEARANCE', widget.data.rankTitle),
                            const SizedBox(height: 7),
                            _telemetryRow('LEVEL', '${hunter.level}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _TickMeter(progress: progress, segments: 14)),
                      const SizedBox(width: 10),
                      _boxedValue('${(progress * 100).round()}%'),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${hunter.xp} / 500 XP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SkinTone.textFaint,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusStrip({required Animation<double> blink}) {
    return Row(
      children: [
        AnimatedBuilder(
          animation: blink,
          builder: (context, _) {
            final pulse = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(blink.value * 2 * math.pi * 3));
            return Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SkinTone.accentBright.withOpacity(pulse.clamp(0.0, 1.0)),
              ),
            );
          },
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'SYS ONLINE',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SkinTone.accentBright,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        const Spacer(),
        Container(width: 26, height: 1, color: SkinTone.line),
      ],
    );
  }

  Widget _bracketAvatar(Uint8List? bytes) {
    return SizedBox(
      width: 62,
      height: 62,
      child: CustomPaint(
        foregroundPainter: _BracketPainter(color: SkinTone.accent),
        child: ClipPath(
          clipper: _CutCornerClipper(cut: 10),
          child: Container(
            color: SkinTone.panelAlt,
            child: bytes != null
                ? Image.memory(bytes, fit: BoxFit.cover, width: 62, height: 62)
                : Center(child: Icon(Icons.person_outline_rounded, color: SkinTone.textSoft, size: 26)),
          ),
        ),
      ),
    );
  }

  Widget _telemetryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            color: SkinTone.textFaint,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(height: 1, color: SkinTone.line),
        ),
        const SizedBox(width: 8),
        Flexible(
          flex: 3,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: SkinTone.textStrong,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _boxedValue(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      border: Border.all(color: SkinTone.accent.withOpacity(0.7)),
      color: SkinTone.accent.withOpacity(0.10),
    ),
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        color: SkinTone.accentBright,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    ),
  );
}

/// Segmented tick meter — the skin's signature progress presentation.
/// Built from `Expanded` segments so it can never overflow at any width.
class _TickMeter extends StatelessWidget {
  const _TickMeter({required this.progress, this.segments = 14, this.height = 12});
  final double progress;
  final int segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * segments).round().clamp(0, segments);
    return Row(
      children: List.generate(segments, (i) {
        final on = i < filled;
        return Expanded(
          child: Container(
            height: height,
            margin: EdgeInsets.only(right: i == segments - 1 ? 0 : 2),
            color: on ? SkinTone.accent : SkinTone.line,
          ),
        );
      }),
    );
  }
}

/// Scanline sweep + machined corner brackets for the hero console.
class _HudFramePainter extends CustomPainter {
  _HudFramePainter({
    required this.t,
    required this.accent,
    required this.accentBright,
    required this.glowStrength,
  });

  final double t;
  final Color accent;
  final Color accentBright;
  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    // Scanline band travelling top → bottom.
    final y = size.height * t;
    final band = Rect.fromLTWH(0, y - 26, size.width, 52);
    final scan = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          accentBright.withOpacity(0),
          accentBright.withOpacity((0.14 * glowStrength).clamp(0.0, 1.0)),
          accentBright.withOpacity(0),
        ],
      ).createShader(band);
    canvas.drawRect(band, scan);

    // Machined corner brackets.
    final stroke = Paint()
      ..color = accent.withOpacity(0.75)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const t2 = 15.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height).deflate(1);
    canvas
      ..drawLine(Offset(r.left, r.top + t2), Offset(r.left, r.top), stroke)
      ..drawLine(Offset(r.left, r.top), Offset(r.left + t2, r.top), stroke)
      ..drawLine(Offset(r.right - t2, r.top), Offset(r.right, r.top), stroke)
      ..drawLine(Offset(r.right, r.top), Offset(r.right, r.top + t2), stroke)
      ..drawLine(Offset(r.left, r.bottom - t2), Offset(r.left, r.bottom), stroke)
      ..drawLine(Offset(r.left, r.bottom), Offset(r.left + t2, r.bottom), stroke)
      ..drawLine(Offset(r.right - t2, r.bottom), Offset(r.right, r.bottom), stroke)
      ..drawLine(Offset(r.right, r.bottom - t2), Offset(r.right, r.bottom), stroke);
  }

  @override
  bool shouldRepaint(covariant _HudFramePainter old) =>
      old.t != t || old.accent != accent || old.accentBright != accentBright || old.glowStrength != glowStrength;
}

/// Corner brackets drawn around the avatar frame.
class _BracketPainter extends CustomPainter {
  _BracketPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    const t = 12.0;
    canvas
      ..drawLine(const Offset(0, t), const Offset(0, 0), p)
      ..drawLine(const Offset(0, 0), const Offset(t, 0), p)
      ..drawLine(Offset(size.width - t, size.height), Offset(size.width, size.height), p)
      ..drawLine(Offset(size.width, size.height - t), Offset(size.width, size.height), p);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) => old.color != color;
}

/// Diagonal top-right corner cut — the Cyber Hunter panel silhouette.
class _CutCornerClipper extends CustomClipper<Path> {
  _CutCornerClipper({this.cut = 12});
  final double cut;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width - cut, 0)
    ..lineTo(size.width, cut)
    ..lineTo(size.width, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ── Quest: telemetry strip ────────────────────────────────────────────────

class _HudQuestStrip extends StatelessWidget {
  const _HudQuestStrip({required this.data});
  final QuestSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SkinTone.panel,
        border: Border.all(color: SkinTone.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipPath(
            clipper: _CutCornerClipper(cut: 9),
            child: Container(
              width: 42,
              height: 42,
              color: SkinTone.accent.withOpacity(0.12),
              child: Icon(Icons.radar_rounded, color: SkinTone.accentBright, size: 20),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'OBJECTIVE SCAN',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textSoft,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    if (data.isComplete) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle_outline_rounded, size: 12, color: SkinTone.complete),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _TickMeter(progress: data.progress, segments: 12, height: 9),
                const SizedBox(height: 7),
                Text(
                  '${data.todaySteps} / ${data.goal} STEPS',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SkinTone.textStrong,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _boxedValue('${(data.progress * 100).round()}%'),
        ],
      ),
    );
  }
}

// ── Stats: 2-column HUD module grid ───────────────────────────────────────

class _HudStatGrid extends StatelessWidget {
  const _HudStatGrid({required this.data});
  final StatsSectionData data;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < data.stats.length; i += 2) {
      final left = data.stats[i];
      final right = (i + 1 < data.stats.length) ? data.stats[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _module(left)),
              const SizedBox(width: 10),
              Expanded(child: right == null ? const SizedBox.shrink() : _module(right)),
            ],
          ),
        ),
      );
      if (i + 2 < data.stats.length) rows.add(const SizedBox(height: 10));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _module(DashboardStat stat) {
    final Color tint = stat.color ?? SkinTone.accent;
    return Container(
      decoration: BoxDecoration(
        color: SkinTone.panel,
        border: Border.all(color: SkinTone.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, color: tint),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(stat.icon, color: tint, size: 12),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        stat.label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textFaint,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    stat.value,
                    maxLines: 1,
                    style: TextStyle(
                      color: SkinTone.textStrong,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
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

// ── Water: segmented tank ─────────────────────────────────────────────────

class _HudTank extends StatelessWidget {
  const _HudTank({required this.data});
  final WaterSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: SkinTone.panel,
        border: Border.all(color: SkinTone.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.opacity_rounded, color: SkinTone.accentBright, size: 14),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'COOLANT LEVEL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SkinTone.textSoft,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Text(
                  '${data.waterIntakeMl} / ${data.waterGoalMl} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: SkinTone.textStrong, fontSize: 11.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TickMeter(progress: data.progress, segments: 18, height: 14),
          const SizedBox(height: 14),
          Row(
            children: [
              _squareBtn(Icons.remove_rounded, data.onRemove),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${data.selectedCupSize} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: SkinTone.textSoft, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 10),
              _squareBtn(Icons.add_rounded, data.onAdd),
              const Spacer(),
              GestureDetector(
                onTap: data.onEditGoal,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(border: Border.all(color: SkinTone.line)),
                  child: Text(
                    'SET GOAL',
                    style: TextStyle(
                      color: SkinTone.textFaint,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _squareBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border.all(color: SkinTone.accent.withOpacity(0.75)),
          color: SkinTone.accent.withOpacity(0.10),
        ),
        child: Icon(icon, size: 15, color: SkinTone.accentBright),
      ),
    );
  }
}

// ── Quick Actions: bracketed console tiles ────────────────────────────────

class _HudConsoleTile extends StatelessWidget {
  const _HudConsoleTile({required this.item});
  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final locked = item.isLocked;
    final tint = locked ? SkinTone.textFaint : SkinTone.accentBright;

    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        foregroundPainter: _BracketPainter(color: locked ? SkinTone.line : SkinTone.accent),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: SkinTone.panel,
            border: Border.all(color: SkinTone.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, color: tint, size: 21),
              const SizedBox(height: 8),
              Text(
                item.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked ? SkinTone.textFaint : SkinTone.textStrong,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                locked ? 'LOCKED' : '>> ENTER',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tint,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

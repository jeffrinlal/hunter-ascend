import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_tone.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Inferno — aggressive combat / heat / angular identity.
///
/// ## Architecture
/// Colors come exclusively from [SkinTone] (→ existing `HunterTheme` tokens →
/// active Premium Theme). No literal color values in this file. Identity is
/// carried by structure, slant geometry, weight and motion.
///
/// ## Composition signature (deliberately unlike every other skin)
/// - **Shape language:** slanted/parallelogram silhouettes and thick
///   load-bearing accent bars. Nothing is symmetrical (vs Frostborn),
///   machined (vs Cyber Hunter) or softly rounded (vs Shadow Monarch).
/// - **Hero:** a **mirrored combat banner** — text block on the LEFT,
///   **hexagonal** avatar hard-right (the inverse of Shadow Monarch's
///   left-avatar layout), a slanted `LV` chip, and a **chevron meter** for
///   XP. The banner's bottom edge is cut on a diagonal; embers pulse
///   along it.
/// - **Quest:** a **combat objective bar** — full-height thick accent spine
///   on the left, stacked readout, and a slanted percentage chip hard-right.
/// - **Stats:** **staggered blocks** at alternating vertical offsets, each
///   carrying a thick left spine (not a list, grid, or diamond row).
/// - **Water:** a heavy **chevron heat gauge** with slanted controls.
/// - **Quick Actions:** two **slanted parallelogram tiles** side by side.
///
/// ## Layout safety
/// All variable text is bounded by `Expanded`/`Flexible`/`FittedBox` +
/// `ellipsis`. Chevron meters are painted to the available width (no fixed
/// widths). Clipped panels reserve bottom padding greater than their diagonal
/// cut so no content is ever clipped. The staggered stats row uses
/// `CrossAxisAlignment.start` with `Expanded` shares, so 3 stats (Basic) and
/// 4 stats (Pro/Max) both fit without overflow.
class InfernoDashboardSections implements DashboardSkinSections {
  const InfernoDashboardSections();

  @override
  Widget hero(HeroSectionData data) => _EmberHero(data: data);

  @override
  Widget quest(QuestSectionData data) => _EmberObjective(data: data);

  @override
  Widget stats(StatsSectionData data) => _EmberBlocks(data: data);

  @override
  Widget water(WaterSectionData data) => _EmberGauge(data: data);

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _EmberTile(item: data.nutrition)),
        const SizedBox(width: 10),
        Expanded(child: _EmberTile(item: data.map)),
      ],
    );
  }
}

// ── Hero: mirrored combat banner ──────────────────────────────────────────

class _EmberHero extends StatefulWidget {
  const _EmberHero({required this.data});
  final HeroSectionData data;

  @override
  State<_EmberHero> createState() => _EmberHeroState();
}

class _EmberHeroState extends State<_EmberHero> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  static const double _cut = 22;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hunter = widget.data.hunter;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;
    final progress = (hunter.xp / 500).clamp(0.0, 1.0);

    return ClipPath(
      clipper: _SlantBannerClipper(cut: _cut),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            // Bottom padding exceeds the diagonal cut so content can never
            // be clipped by the slanted edge.
            padding: const EdgeInsets.fromLTRB(18, 18, 18, _cut + 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [SkinTone.backdropTop, SkinTone.backdropBottom],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(width: 3, height: 13, color: SkinTone.accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              widget.data.rankTitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SkinTone.accentBright,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hunter.hunterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textStrong,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 9),
                      _slantChip('LV ${hunter.level}'),
                      const SizedBox(height: 15),
                      _ChevronBar(progress: progress, height: 13),
                      const SizedBox(height: 7),
                      Text(
                        '${hunter.xp} / 500 XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textFaint,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                _HexAvatar(bytes: avatarBytes, pulse: _pulse),
              ],
            ),
          ),
          // Ember heat pulse along the slanted bottom edge. Decorative only.
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) => CustomPaint(
                  painter: _EmberHeatPainter(
                    t: _pulse.value,
                    accent: SkinTone.accent,
                    accentBright: SkinTone.accentBright,
                    glowStrength: SkinTone.glow,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _slantChip(String text) {
    return ClipPath(
      clipper: _ParallelogramClipper(slant: 7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        color: SkinTone.accent.withOpacity(0.18),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: SkinTone.accentBright,
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

class _HexAvatar extends StatelessWidget {
  const _HexAvatar({required this.bytes, required this.pulse});
  final Uint8List? bytes;
  final Animation<double> pulse;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return SizedBox(
          width: _size,
          height: _size,
          child: CustomPaint(
            foregroundPainter: _HexEdgePainter(
              color: SkinTone.accentBright,
              intensity: 0.55 + 0.45 * pulse.value,
              glowStrength: SkinTone.glow,
            ),
            child: ClipPath(
              clipper: _HexClipper(),
              child: Container(
                color: SkinTone.accent.withOpacity(0.16),
                child: bytes != null
                    ? Image.memory(bytes!, fit: BoxFit.cover, width: _size, height: _size)
                    : Center(child: Icon(Icons.person_rounded, color: SkinTone.textSoft, size: 28)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Chevron meter — the skin's signature progress language: a heavy track
/// with slanted segment separators cut across it. Painted to the available
/// width, so it cannot overflow.
class _ChevronBar extends StatelessWidget {
  const _ChevronBar({required this.progress, this.height = 12});
  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChevronBarPainter(
            progress: v,
            track: SkinTone.line,
            fillA: SkinTone.accentRamp.first,
            fillB: SkinTone.accentRamp.last,
            cutColor: SkinTone.backdropBottom,
          ),
        ),
      ),
    );
  }
}

class _ChevronBarPainter extends CustomPainter {
  _ChevronBarPainter({
    required this.progress,
    required this.track,
    required this.fillA,
    required this.fillB,
    required this.cutColor,
  });

  final double progress;
  final Color track;
  final Color fillA;
  final Color fillB;
  final Color cutColor;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(full, Paint()..color = track);

    final fillW = size.width * progress.clamp(0.0, 1.0);
    if (fillW > 0) {
      final fillRect = Rect.fromLTWH(0, 0, fillW, size.height);
      canvas.drawRect(
        fillRect,
        Paint()..shader = LinearGradient(colors: [fillA, fillB]).createShader(fillRect),
      );
    }

    // Slanted separators cut across the whole bar — the chevron rhythm.
    final sep = Paint()
      ..color = cutColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;
    const step = 15.0;
    final slant = size.height;
    for (double x = step; x < size.width + slant; x += step) {
      canvas.drawLine(Offset(x, size.height), Offset(x - slant, 0), sep);
    }
  }

  @override
  bool shouldRepaint(covariant _ChevronBarPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.fillA != fillA ||
      old.fillB != fillB ||
      old.cutColor != cutColor;
}

class _EmberHeatPainter extends CustomPainter {
  _EmberHeatPainter({
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
    final flicker = 0.55 + 0.45 * math.sin(t * 2 * math.pi);

    // Heat bloom rising from the bottom-left (the deep side of the cut).
    canvas.drawCircle(
      Offset(size.width * 0.12, size.height * 1.02),
      size.shortestSide * 0.62,
      Paint()
        ..color = accent.withOpacity((0.16 * flicker * glowStrength).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 44),
    );

    // Sharper ember highlight near the right shoulder.
    canvas.drawCircle(
      Offset(size.width * 0.92, size.height * 0.08),
      size.shortestSide * 0.30,
      Paint()
        ..color = accentBright.withOpacity((0.12 * (1.4 - flicker) * glowStrength).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 34),
    );
  }

  @override
  bool shouldRepaint(covariant _EmberHeatPainter old) =>
      old.t != t || old.accent != accent || old.accentBright != accentBright || old.glowStrength != glowStrength;
}

// ── Clippers ──────────────────────────────────────────────────────────────

/// Banner with a diagonal bottom edge (deepest at bottom-left).
class _SlantBannerClipper extends CustomClipper<Path> {
  _SlantBannerClipper({this.cut = 22});
  final double cut;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width, size.height - cut)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _ParallelogramClipper extends CustomClipper<Path> {
  _ParallelogramClipper({this.slant = 8});
  final double slant;

  @override
  Path getClip(Size size) => Path()
    ..moveTo(slant, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - slant, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * 0.26, 0)
    ..lineTo(size.width * 0.74, 0)
    ..lineTo(size.width, size.height * 0.5)
    ..lineTo(size.width * 0.74, size.height)
    ..lineTo(size.width * 0.26, size.height)
    ..lineTo(0, size.height * 0.5)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HexEdgePainter extends CustomPainter {
  _HexEdgePainter({required this.color, required this.intensity, required this.glowStrength});
  final Color color;
  final double intensity;
  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.26, 0)
      ..lineTo(size.width * 0.74, 0)
      ..lineTo(size.width, size.height * 0.5)
      ..lineTo(size.width * 0.74, size.height)
      ..lineTo(size.width * 0.26, size.height)
      ..lineTo(0, size.height * 0.5)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity((0.34 * intensity * glowStrength).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _HexEdgePainter old) =>
      old.color != color || old.intensity != intensity || old.glowStrength != glowStrength;
}

// ── Quest: combat objective bar ───────────────────────────────────────────

class _EmberObjective extends StatelessWidget {
  const _EmberObjective({required this.data});
  final QuestSectionData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-height accent spine — the section's load-bearing element.
            Container(width: 5, color: SkinTone.accent),
            Expanded(
              child: Container(
                color: SkinTone.panel,
                padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.whatshot_rounded, size: 14, color: SkinTone.accentBright),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  'BURN TARGET',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: SkinTone.textSoft,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.7,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 9),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${data.todaySteps}',
                                  maxLines: 1,
                                  style: TextStyle(color: SkinTone.textStrong, fontSize: 23, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '/ ${data.goal}',
                                  maxLines: 1,
                                  style: TextStyle(color: SkinTone.textFaint, fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 11),
                          _ChevronBar(progress: data.progress, height: 11),
                          if (data.isComplete) ...[
                            const SizedBox(height: 9),
                            Text(
                              'TARGET DOWN',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: SkinTone.complete,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipPath(
                      clipper: _ParallelogramClipper(slant: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                        color: SkinTone.accent.withOpacity(0.18),
                        child: Text(
                          '${(data.progress * 100).round()}%',
                          maxLines: 1,
                          style: TextStyle(
                            color: SkinTone.accentBright,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats: staggered blocks ───────────────────────────────────────────────

class _EmberBlocks extends StatelessWidget {
  const _EmberBlocks({required this.data});
  final StatsSectionData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(data.stats.length, (i) {
        final isOffset = i.isOdd;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              top: isOffset ? 14 : 0,
              right: i == data.stats.length - 1 ? 0 : 8,
            ),
            child: _block(data.stats[i]),
          ),
        );
      }),
    );
  }

  Widget _block(DashboardStat stat) {
    final tint = stat.color ?? SkinTone.accent;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 11, 8, 11),
      decoration: BoxDecoration(
        color: SkinTone.panel,
        border: Border(left: BorderSide(color: tint, width: 3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(stat.icon, color: tint, size: 14),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              stat.value,
              maxLines: 1,
              style: TextStyle(color: SkinTone.textStrong, fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: SkinTone.textFaint,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Water: chevron heat gauge ─────────────────────────────────────────────

class _EmberGauge extends StatelessWidget {
  const _EmberGauge({required this.data});
  final WaterSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: SkinTone.panel,
        border: Border(left: BorderSide(color: SkinTone.accent, width: 5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_drink_rounded, size: 14, color: SkinTone.accentBright),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'QUENCH METER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SkinTone.textSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.7,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                flex: 2,
                child: Text(
                  '${data.waterIntakeMl} / ${data.waterGoalMl} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: SkinTone.textStrong, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChevronBar(progress: data.progress, height: 16),
          const SizedBox(height: 16),
          Row(
            children: [
              _slantBtn(Icons.remove_rounded, data.onRemove),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  '${data.selectedCupSize} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: SkinTone.textSoft, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              _slantBtn(Icons.add_rounded, data.onAdd),
              const Spacer(),
              GestureDetector(
                onTap: data.onEditGoal,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'GOAL',
                  style: TextStyle(
                    color: SkinTone.accentBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _slantBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipPath(
        clipper: _ParallelogramClipper(slant: 6),
        child: Container(
          width: 38,
          height: 30,
          color: SkinTone.accent.withOpacity(0.2),
          child: Icon(icon, size: 16, color: SkinTone.accentBright),
        ),
      ),
    );
  }
}

// ── Quick Actions: slanted tiles ──────────────────────────────────────────

class _EmberTile extends StatelessWidget {
  const _EmberTile({required this.item});
  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final locked = item.isLocked;
    final tint = locked ? SkinTone.textFaint : SkinTone.accentBright;

    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipPath(
        clipper: _ParallelogramClipper(slant: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
            color: SkinTone.panel,
            border: Border(
              left: BorderSide(color: locked ? SkinTone.line : SkinTone.accent, width: 3),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: tint, size: 21),
              const SizedBox(height: 9),
              Text(
                item.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: locked ? SkinTone.textFaint : SkinTone.textStrong,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.9,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      locked ? 'LOCKED' : 'ENGAGE',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tint,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, size: 12, color: tint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

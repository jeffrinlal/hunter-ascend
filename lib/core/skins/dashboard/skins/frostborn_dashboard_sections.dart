import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_tone.dart';
import 'package:hunter_ascend/widgets/dashboard/dashboard_stats_grid.dart';

/// Frostborn — elegant ice / crystal / glass identity.
///
/// ## Architecture
/// Colors come exclusively from [SkinTone] (→ existing `HunterTheme` tokens →
/// active Premium Theme). No literal color values in this file. Identity is
/// carried by structure, geometry, spacing rhythm and motion.
///
/// ## Composition signature (deliberately unlike every other skin)
/// - **Shape language:** diamond/crystal geometry + soft large radii (22–26)
///   + layered translucent "frosted glass" sheets. The opposite of Cyber
///   Hunter's hard machined brackets and Inferno's slanted aggression.
/// - **Hero:** a **centered, spacious ceremonial composition** — diamond
///   avatar centred at the top, name and rank centre-aligned beneath it,
///   then a crystal **shard meter** above a hairline rail. Nothing is
///   left-aligned (Shadow Monarch) or telemetry-tabulated (Cyber Hunter).
///   A slow diagonal glint sweeps the glass; fine ice particles drift up.
/// - **Quest:** a **centre-aligned trial card** — centred label, centred
///   large numeral, wide shard meter. Symmetrical, airy.
/// - **Stats:** a **horizontal row of diamond badges**, value + label
///   stacked beneath each (not a list, grid, or staggered blocks).
/// - **Water:** glass panel with a **full-width shard fill** and
///   **centre-aligned soft controls** below (controls below, not beside).
/// - **Quick Actions:** a **single unified glass panel split by one vertical
///   hairline** — one surface, two halves. Every other skin uses two
///   separate tiles/rows.
///
/// ## Layout safety
/// All variable text is bounded with `Flexible`/`Expanded`/`FittedBox` +
/// `ellipsis`. Shard meters use `Expanded` segments (water) or a centred
/// fixed-count row that fits the narrowest phone (hero/quest). The stats row
/// gives every badge an equal `Expanded` share with `FittedBox` values, so 3
/// stats (Basic) and 4 stats (Pro/Max) both fit without overflow.
class FrostbornDashboardSections implements DashboardSkinSections {
  const FrostbornDashboardSections();

  @override
  Widget hero(HeroSectionData data) => _FrostHero(data: data);

  @override
  Widget quest(QuestSectionData data) => _FrostTrial(data: data);

  @override
  Widget stats(StatsSectionData data) => _FrostDiamonds(data: data);

  @override
  Widget water(WaterSectionData data) => _FrostVessel(data: data);

  @override
  Widget quickActions(QuickActionsSectionData data) => _FrostSplitPanel(data: data);
}

/// Shared frosted-glass surface: layered translucent sheet + hairline edge.
class _Glass extends StatelessWidget {
  const _Glass({required this.child, this.radius = 22, this.padding});
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: SkinTone.line),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            SkinTone.panelAlt,
            SkinTone.panel,
          ],
        ),
      ),
      child: child,
    );
  }
}

// ── Hero: centred ceremonial composition ──────────────────────────────────

class _FrostHero extends StatefulWidget {
  const _FrostHero({required this.data});
  final HeroSectionData data;

  @override
  State<_FrostHero> createState() => _FrostHeroState();
}

class _FrostHeroState extends State<_FrostHero> with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 7000),
  )..repeat();

  @override
  void dispose() {
    _drift.dispose();
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
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          _Glass(
            radius: 26,
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DiamondAvatar(bytes: avatarBytes),
                const SizedBox(height: 18),
                Text(
                  hunter.hunterName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SkinTone.textStrong,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.data.rankTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SkinTone.accentBright,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.6,
                  ),
                ),
                const SizedBox(height: 20),
                _ShardMeter(progress: progress, count: 12),
                const SizedBox(height: 12),
                _HairlineRail(progress: progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'LEVEL ${hunter.level}',
                      style: TextStyle(
                        color: SkinTone.textSoft,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: SkinTone.textFaint)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${hunter.xp} / 500 XP',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textFaint,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Glint sweep + drifting ice particles. Decorative only, clipped
          // to the panel, ignores pointers, never overlaps text legibility.
          Positioned.fill(
            child: IgnorePointer(
              // Repaint isolation only. This decorative overlay repaints on
              // every `_drift` frame, while the glass panel below it changes
              // only when hunter data does. Without a boundary each tick marks
              // the whole hero panel's layer dirty. Identical painter,
              // animation, duration and colours — only the repaint scope
              // changes. Mirrors widgets/premium_card_decorator.dart.
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => CustomPaint(
                    painter: _FrostAtmospherePainter(
                      t: _drift.value,
                      accent: SkinTone.accentBright,
                      highlight: SkinTone.textStrong,
                      glowStrength: SkinTone.glow,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiamondAvatar extends StatelessWidget {
  const _DiamondAvatar({required this.bytes});
  final Uint8List? bytes;

  static const double _size = 74;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        foregroundPainter: _DiamondEdgePainter(
          color: SkinTone.accentBright,
          glowStrength: SkinTone.glow,
        ),
        child: ClipPath(
          clipper: _DiamondClipper(),
          child: Container(
            color: SkinTone.accent.withOpacity(0.14),
            child: bytes != null
                ? Image.memory(bytes!, fit: BoxFit.cover, width: _size, height: _size)
                : Center(child: Icon(Icons.person_rounded, color: SkinTone.textSoft, size: 26)),
          ),
        ),
      ),
    );
  }
}

/// Crystal shard progress meter — the skin's signature progress language.
/// Fixed-count centred row sized to fit the narrowest supported phone.
class _ShardMeter extends StatelessWidget {
  const _ShardMeter({required this.progress, this.count = 12, this.shardWidth = 9, this.shardHeight = 15});
  final double progress;
  final int count;
  final double shardWidth;
  final double shardHeight;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * count).round().clamp(0, count);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final on = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SizedBox(
            width: shardWidth,
            height: shardHeight,
            child: ClipPath(
              clipper: _DiamondClipper(),
              child: Container(color: on ? SkinTone.accentBright : SkinTone.line),
            ),
          ),
        );
      }),
    );
  }
}

class _HairlineRail extends StatelessWidget {
  const _HairlineRail({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 3,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: SkinTone.line),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(gradient: LinearGradient(colors: SkinTone.accentRamp)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiamondClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width / 2, 0)
    ..lineTo(size.width, size.height / 2)
    ..lineTo(size.width / 2, size.height)
    ..lineTo(0, size.height / 2)
    ..close();

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _DiamondEdgePainter extends CustomPainter {
  _DiamondEdgePainter({required this.color, required this.glowStrength});
  final Color color;
  final double glowStrength;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(0, size.height / 2)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity((0.30 * glowStrength).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
  }

  @override
  bool shouldRepaint(covariant _DiamondEdgePainter old) =>
      old.color != color || old.glowStrength != glowStrength;
}

/// Diagonal glint sweep + drifting ice motes.
class _FrostAtmospherePainter extends CustomPainter {
  _FrostAtmospherePainter({
    required this.t,
    required this.accent,
    required this.highlight,
    required this.glowStrength,
  });

  final double t;
  final Color accent;
  final Color highlight;
  final double glowStrength;

  static final List<_Mote> _motes = List.generate(14, (i) {
    final rng = math.Random(i * 37 + 11);
    return _Mote(x: rng.nextDouble(), phase: rng.nextDouble(), size: 0.8 + rng.nextDouble() * 1.6, speed: 0.4 + rng.nextDouble() * 0.6);
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal glint band.
    final progress = (t * 1.6) % 1.6 - 0.3;
    final cx = size.width * progress;
    final band = Path()
      ..moveTo(cx, -10)
      ..lineTo(cx + 44, -10)
      ..lineTo(cx + 44 - size.height * 0.5, size.height + 10)
      ..lineTo(cx - size.height * 0.5, size.height + 10)
      ..close();
    canvas.drawPath(
      band,
      Paint()
        ..color = highlight.withOpacity((0.05 * glowStrength).clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Drifting motes.
    for (final m in _motes) {
      final y = (1.0 - ((m.phase + t * m.speed) % 1.0)) * size.height;
      final fade = 1.0 - (y / size.height - 0.5).abs() * 2;
      canvas.drawCircle(
        Offset(m.x * size.width, y),
        m.size,
        Paint()..color = accent.withOpacity((fade * 0.35 * glowStrength).clamp(0.0, 1.0)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FrostAtmospherePainter old) =>
      old.t != t || old.accent != accent || old.highlight != highlight || old.glowStrength != glowStrength;
}

class _Mote {
  const _Mote({required this.x, required this.phase, required this.size, required this.speed});
  final double x, phase, size, speed;
}

// ── Quest: centred trial card ─────────────────────────────────────────────

class _FrostTrial extends StatelessWidget {
  const _FrostTrial({required this.data});
  final QuestSectionData data;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.ac_unit_rounded, size: 12, color: SkinTone.accentBright),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'FROST TRIAL',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SkinTone.textSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${data.todaySteps}',
                  maxLines: 1,
                  style: TextStyle(color: SkinTone.textStrong, fontSize: 27, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 7),
                Text(
                  '/ ${data.goal}',
                  maxLines: 1,
                  style: TextStyle(color: SkinTone.textFaint, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ShardMeter(progress: data.progress, count: 10, shardWidth: 11, shardHeight: 18),
          const SizedBox(height: 14),
          Text(
            data.isComplete ? 'Trial cleared' : 'Trial in progress',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: data.isComplete ? SkinTone.complete : SkinTone.textFaint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats: diamond badge row ──────────────────────────────────────────────

class _FrostDiamonds extends StatelessWidget {
  const _FrostDiamonds({required this.data});
  final StatsSectionData data;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.stats.map((s) => Expanded(child: _badge(s))).toList(),
      ),
    );
  }

  Widget _badge(DashboardStat stat) {
    final tint = stat.color ?? SkinTone.accentBright;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipPath(
                  clipper: _DiamondClipper(),
                  child: Container(color: tint.withOpacity(0.16)),
                ),
                CustomPaint(
                  size: const Size(42, 42),
                  painter: _DiamondEdgePainter(color: tint, glowStrength: SkinTone.glow * 0.6),
                ),
                Icon(stat.icon, color: tint, size: 15),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              stat.value,
              maxLines: 1,
              style: TextStyle(color: SkinTone.textStrong, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: SkinTone.textFaint, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

// ── Water: glass vessel, controls centred below ───────────────────────────

class _FrostVessel extends StatelessWidget {
  const _FrostVessel({required this.data});
  final WaterSectionData data;

  @override
  Widget build(BuildContext context) {
    const segments = 10;
    final filled = (data.progress * segments).round().clamp(0, segments);

    return _Glass(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.water_drop_outlined, size: 13, color: SkinTone.accentBright),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'MELTWATER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: SkinTone.textSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
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
                  style: TextStyle(color: SkinTone.textStrong, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Full-width shard fill — Expanded segments, cannot overflow.
          Row(
            children: List.generate(segments, (i) {
              final on = i < filled;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: SizedBox(
                    height: 20,
                    child: ClipPath(
                      clipper: _DiamondClipper(),
                      child: Container(color: on ? SkinTone.accentBright : SkinTone.line),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _softBtn(Icons.remove_rounded, data.onRemove),
              const SizedBox(width: 16),
              Flexible(
                child: Text(
                  '${data.selectedCupSize} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: SkinTone.textSoft, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 16),
              _softBtn(Icons.add_rounded, data.onAdd),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: data.onEditGoal,
              behavior: HitTestBehavior.opaque,
              child: Text(
                'Adjust goal',
                style: TextStyle(
                  color: SkinTone.accentBright,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _softBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: SkinTone.accent.withOpacity(0.12),
          border: Border.all(color: SkinTone.accentBright.withOpacity(0.45)),
        ),
        child: Icon(icon, size: 17, color: SkinTone.accentBright),
      ),
    );
  }
}

// ── Quick Actions: one unified glass panel, split by a hairline ────────────

class _FrostSplitPanel extends StatelessWidget {
  const _FrostSplitPanel({required this.data});
  final QuickActionsSectionData data;

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _half(data.nutrition)),
            Container(width: 1, color: SkinTone.line),
            Expanded(child: _half(data.map)),
          ],
        ),
      ),
    );
  }

  Widget _half(QuickActionItem item) {
    final locked = item.isLocked;
    final tint = locked ? SkinTone.textFaint : SkinTone.accentBright;

    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipPath(
                    clipper: _DiamondClipper(),
                    child: Container(color: tint.withOpacity(0.15)),
                  ),
                  Icon(item.icon, color: tint, size: 15),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: locked ? SkinTone.textFaint : SkinTone.textStrong,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            if (locked) ...[
              const SizedBox(height: 3),
              Icon(Icons.lock_outline_rounded, size: 11, color: SkinTone.textFaint),
            ],
          ],
        ),
      ),
    );
  }
}

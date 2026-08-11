import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Inferno — "Combat Panel" identity.
///
/// Structural signature: every panel has a jagged/torn bottom edge (like
/// scorched paper) instead of a rounded or clean-cut silhouette; the hero
/// is a wide, low banner with the avatar in a spiked circular frame
/// pushed to the RIGHT edge and name/level stacked on the LEFT (mirrored
/// composition vs. Shadow Monarch's left-avatar layout, and unlike Pro/
/// Max's centered/floating patterns); stats render as staggered
/// alternating-offset blocks (not a uniform row/grid/list); the quest
/// card shows progress as a horizontal row of flame-icon "embers" lighting
/// up left-to-right; quick actions are two angled slanted-parallelogram
/// tiles. Colors always come from [HeroSectionData.accentColor] / the live
/// `MembershipTheme.current` token plus existing `HunterTheme` tokens.
class InfernoDashboardSections implements DashboardSkinSections {
  const InfernoDashboardSections();

  @override
  Widget hero(HeroSectionData data) {
    final hunter = data.hunter;
    final accent = data.accentColor;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;

    return SkinAwareSurface(
      borderRadius: 18,
      child: ClipPath(
        clipper: _JaggedBottomClipper(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accent.withOpacity(0.20), HunterTheme.cardColor],
            ),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.rankTitle.toUpperCase(),
                        style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(hunter.hunterName,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 19, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('LEVEL ${hunter.level}', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    // Ember-row XP meter: small flame icons lighting up.
                    Row(
                      children: List.generate(8, (i) {
                        final on = i < ((hunter.xp / 500) * 8).round();
                        return Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: Icon(Icons.local_fire_department_rounded, size: 14, color: on ? accent : HunterTheme.border),
                        );
                      }),
                    ),
                    const SizedBox(height: 4),
                    Text('${hunter.xp} / 500 XP', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Spiked circular frame, pushed to the right edge.
              CustomPaint(
                foregroundPainter: _SpikeRingPainter(color: accent),
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: accent.withOpacity(0.16)),
                  padding: const EdgeInsets.all(6),
                  child: ClipOval(
                    child: avatarBytes != null
                        ? Image.memory(avatarBytes, fit: BoxFit.cover)
                        : Container(color: HunterTheme.cardColor, child: Icon(Icons.person, color: accent, size: 30)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget quest(QuestSectionData data) {
    return SkinAwareSurface(
      borderRadius: 18,
      child: ClipPath(
        clipper: _JaggedBottomClipper(toothHeight: 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: _accent.withOpacity(0.35))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.whatshot_rounded, color: _accent, size: 18),
                const SizedBox(width: 8),
                Text('BURN TARGET', style: TextStyle(color: _accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const Spacer(),
                Text('${(data.progress * 100).round()}%', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              Text('${data.todaySteps} / ${data.goal} steps',
                  style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Row(
                children: List.generate(10, (i) {
                  final on = i < (data.progress * 10).round();
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      child: Icon(Icons.local_fire_department_rounded, size: 16, color: on ? _accent : HunterTheme.border),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget stats(StatsSectionData data) {
    return Row(
      children: List.generate(data.stats.length, (i) {
        final s = data.stats[i];
        final offset = i.isOdd ? 10.0 : 0.0;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: offset, right: 6),
            child: _staggerBlock(s.icon, s.value, s.label, s.color ?? _accent),
          ),
        );
      }),
    );
  }

  Widget _staggerBlock(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget water(WaterSectionData data) {
    return ClipPath(
      clipper: _JaggedBottomClipper(toothHeight: 6),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: _accent.withOpacity(0.35))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.local_fire_department_outlined, color: _accent, size: 16),
              const SizedBox(width: 8),
              Text('QUENCH METER', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const Spacer(),
              Text('${data.waterIntakeMl}/${data.waterGoalMl}ml', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 10),
            Stack(children: [
              Container(height: 10, color: HunterTheme.border),
              FractionallySizedBox(widthFactor: data.progress, child: Container(height: 10, color: _accent)),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _angledBtn(Icons.remove, data.onRemove),
              const SizedBox(width: 18),
              Text('${data.selectedCupSize}ml', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 18),
              _angledBtn(Icons.add, data.onAdd),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _angledBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Transform.rotate(
        angle: -0.12,
        child: Container(width: 30, height: 30, color: _accent.withOpacity(0.16), child: Icon(icon, size: 16, color: _accent)),
      ),
    );
  }

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Row(children: [
      Expanded(child: _slantTile(data.nutrition)),
      const SizedBox(width: 10),
      Expanded(child: _slantTile(data.map)),
    ]);
  }

  Widget _slantTile(QuickActionItem item) {
    final color = item.isLocked ? HunterTheme.textTertiary : _accent;
    return GestureDetector(
      onTap: item.onTap,
      child: Transform.rotate(
        angle: -0.02,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: color.withOpacity(0.55), width: 1.3)),
          child: Column(children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(item.label, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Jagged/torn bottom edge — the shared silhouette signature for every
/// Inferno panel.
class _JaggedBottomClipper extends CustomClipper<Path> {
  _JaggedBottomClipper({this.toothHeight = 8, this.teeth = 6});
  final double toothHeight;
  final int teeth;

  @override
  Path getClip(Size size) {
    final segment = size.width / teeth;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - toothHeight);
    for (int i = teeth; i >= 0; i--) {
      final x = segment * i;
      final y = i.isEven ? size.height : size.height - toothHeight;
      path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _SpikeRingPainter extends CustomPainter {
  _SpikeRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final paint = Paint()..color = color;
    const spikes = 10;
    for (int i = 0; i < spikes; i++) {
      final angle = (i / spikes) * 2 * math.pi;
      final outer = Offset(center.dx + (radius + 5) * math.cos(angle), center.dy + (radius + 5) * math.sin(angle));
      final baseA = Offset(center.dx + radius * math.cos(angle - 0.09), center.dy + radius * math.sin(angle - 0.09));
      final baseB = Offset(center.dx + radius * math.cos(angle + 0.09), center.dy + radius * math.sin(angle + 0.09));
      final path = Path()..moveTo(baseA.dx, baseA.dy)..lineTo(outer.dx, outer.dy)..lineTo(baseB.dx, baseB.dy)..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpikeRingPainter oldDelegate) => oldDelegate.color != color;
}

Color get _accent => MembershipTheme.current.accent;

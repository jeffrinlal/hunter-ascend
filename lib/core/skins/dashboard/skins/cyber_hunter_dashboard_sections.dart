import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Cyber Hunter — "HUD Panel" identity.
///
/// Structural signature: every card is a bracket-cornered HUD panel
/// (tick-mark corners, sharp edges) instead of a rounded card; the hero
/// splits into a LEFT readout column (level/name as monospace-style
/// stacked labels) + RIGHT square avatar panel — never the floating-avatar-
/// over-hero pattern Pro/Max use; stats render as a 2-COLUMN GRID of
/// diagonal-cut tiles (not a horizontal row or vertical list); the quest
/// card is a horizontal "scan" readout with a percentage counter instead
/// of a fill bar; quick actions are two side-by-side bracket tiles with a
/// ">>" affordance instead of icon-over-label squares. Colors always come
/// from [HeroSectionData.accentColor] / the live `MembershipTheme.current`
/// token plus existing `HunterTheme` tokens.
class CyberHunterDashboardSections implements DashboardSkinSections {
  const CyberHunterDashboardSections();

  @override
  Widget hero(HeroSectionData data) {
    final hunter = data.hunter;
    final accent = data.accentColor;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;
    final progress = (hunter.xp / 500).clamp(0.0, 1.0);

    return SkinAwareSurface(
      borderRadius: 10,
      child: _HudPanel(
        accent: accent,
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IDENTIFIER', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  Text(hunter.hunterName,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text('CLEARANCE', style: TextStyle(color: accent, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2)),
                  Text(data.rankTitle.toUpperCase(),
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Text('LVL.${hunter.level}  //  ${hunter.xp}/500XP',
                      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  // Thin bracketed scan-bar (still a "bar", but framed by
                  // tick marks instead of a rounded gradient track).
                  Stack(children: [
                    Container(height: 4, color: HunterTheme.border),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(height: 4, color: accent),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 14),
            ClipPath(
              clipper: _DiagonalCornerClipper(),
              child: Container(
                width: 64,
                height: 64,
                color: accent.withOpacity(0.16),
                padding: const EdgeInsets.all(2),
                child: avatarBytes != null
                    ? Image.memory(avatarBytes, fit: BoxFit.cover)
                    : Container(color: HunterTheme.cardColor, child: Icon(Icons.person, color: accent, size: 30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget quest(QuestSectionData data) {
    return SkinAwareSurface(
      borderRadius: 10,
      child: _HudPanel(
        accent: _accent,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.radar_rounded, color: _accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OBJECTIVE SCAN', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text('${data.todaySteps} / ${data.goal} STEPS',
                      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            Text('${(data.progress * 100).round()}%',
                style: TextStyle(color: data.isComplete ? HunterTheme.success : _accent, fontSize: 22, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  @override
  Widget stats(StatsSectionData data) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: data.stats.map((s) => _diagonalTile(s.icon, s.value, s.label, s.color ?? _accent)).toList(),
    );
  }

  Widget _diagonalTile(IconData icon, String value, String label, Color color) {
    return ClipPath(
      clipper: _DiagonalCornerClipper(cut: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: HunterTheme.cardColor,
        child: Stack(
          children: [
            Positioned(top: 0, left: 0, right: 0, height: 2, child: Container(color: color)),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(icon, color: color, size: 14),
                    const SizedBox(width: 6),
                    Text(label.toUpperCase(), style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ]),
                  const SizedBox(height: 4),
                  Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget water(WaterSectionData data) {
    return _HudPanel(
      accent: _accent,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.opacity_rounded, color: _accent, size: 16),
            const SizedBox(width: 8),
            Text('COOLANT LEVEL', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            const Spacer(),
            Text('${data.waterIntakeMl}/${data.waterGoalMl}ml', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11)),
          ]),
          const SizedBox(height: 10),
          // Segmented horizontal HUD meter (blocks, not a smooth gradient).
          Row(
            children: List.generate(16, (i) {
              final on = i < (data.progress * 16).round();
              return Expanded(
                child: Container(
                  height: 10,
                  margin: const EdgeInsets.only(right: 2),
                  color: on ? _accent : HunterTheme.border,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _bracketBtn(Icons.remove, data.onRemove),
            const SizedBox(width: 20),
            Text('${data.selectedCupSize}ml', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(width: 20),
            _bracketBtn(Icons.add, data.onAdd),
          ]),
        ],
      ),
    );
  }

  Widget _bracketBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(border: Border.all(color: _accent)),
        child: Icon(icon, size: 16, color: _accent),
      ),
    );
  }

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Row(children: [
      Expanded(child: _bracketTile(data.nutrition)),
      const SizedBox(width: 10),
      Expanded(child: _bracketTile(data.map)),
    ]);
  }

  Widget _bracketTile(QuickActionItem item) {
    final color = item.isLocked ? HunterTheme.textTertiary : _accent;
    return GestureDetector(
      onTap: item.onTap,
      child: _HudPanel(
        accent: color,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(item.icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(item.label.toUpperCase(), style: TextStyle(color: HunterTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 2),
            Text(item.isLocked ? 'LOCKED' : '>> ENTER', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Bracket-cornered HUD panel: sharp rectangle with short corner ticks
/// drawn in [accent] — the Cyber Hunter equivalent of a "card."
class _HudPanel extends StatelessWidget {
  const _HudPanel({required this.child, required this.accent, this.padding});
  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _HudCornerPainter(color: accent),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: child,
      ),
    );
  }
}

class _HudCornerPainter extends CustomPainter {
  _HudCornerPainter({required this.color});
  final Color color;
  static const double _tick = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(const Offset(0, 0), const Offset(_tick, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, _tick), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - _tick, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, _tick), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - _tick), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(_tick, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - _tick, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - _tick), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _HudCornerPainter oldDelegate) => oldDelegate.color != color;
}

class _DiagonalCornerClipper extends CustomClipper<Path> {
  _DiagonalCornerClipper({this.cut = 14});
  final double cut;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width - cut, 0)
      ..lineTo(size.width, cut)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Color get _accent => MembershipTheme.current.accent;

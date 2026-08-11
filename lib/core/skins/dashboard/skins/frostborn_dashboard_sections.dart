import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Frostborn — "Crystal Facet" identity.
///
/// Structural signature: every panel is clipped into an angular, faceted
/// silhouette (one corner cut at 45°, like a cut gem) instead of a rounded
/// rectangle; the hero centers the avatar inside a DIAMOND frame above the
/// name/level (a vertical stack, not Pro/Max's floating-ring-over-banner or
/// Shadow Monarch's left-aligned frame); stats render as a horizontal row
/// of DIAMOND badges (rotated squares) instead of chips/pills/rows; the
/// quest card shows progress as a vertical "icicle" column of small
/// triangles filling upward; quick actions are two hexagon-cut tiles.
/// Colors always come from [HeroSectionData.accentColor] / the live
/// `MembershipTheme.current` token plus existing `HunterTheme` tokens.
class FrostbornDashboardSections implements DashboardSkinSections {
  const FrostbornDashboardSections();

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
        clipper: _FacetClipper(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [accent.withOpacity(0.14), HunterTheme.cardColor],
            ),
            border: Border.all(color: accent.withOpacity(0.35)),
          ),
          child: Column(
            children: [
              // Diamond-framed avatar, centered — vertical stack, not a
              // floating ring overlapping a banner edge.
              Transform.rotate(
                angle: 0.785398, // 45deg — diamond
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    border: Border.all(color: accent, width: 2),
                  ),
                  child: Transform.rotate(
                    angle: -0.785398,
                    child: avatarBytes != null
                        ? ClipRect(child: Image.memory(avatarBytes, fit: BoxFit.cover))
                        : Icon(Icons.person, color: accent, size: 30),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(hunter.hunterName,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(data.rankTitle.toUpperCase(),
                  style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _iceShard(filled: true),
                  _iceShard(filled: hunter.level > 0),
                  Text('  LV.${hunter.level}  ', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                  _iceShard(filled: true),
                  _iceShard(filled: true),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: Stack(children: [
                  Container(height: 5, color: HunterTheme.border),
                  FractionallySizedBox(
                    widthFactor: (hunter.xp / 500).clamp(0.0, 1.0),
                    child: Container(height: 5, color: accent),
                  ),
                ]),
              ),
              const SizedBox(height: 4),
              Text('${hunter.xp} / 500 XP', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iceShard({required bool filled}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.change_history_rounded, size: 10, color: filled ? _accent : HunterTheme.border),
    );
  }

  @override
  Widget quest(QuestSectionData data) {
    return SkinAwareSurface(
      borderRadius: 18,
      child: ClipPath(
        clipper: _FacetClipper(cut: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: _accent.withOpacity(0.3))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical icicle column — triangles filling upward.
              SizedBox(
                width: 20,
                height: 60,
                child: Column(
                  children: List.generate(6, (i) {
                    final rowFromBottom = 5 - i;
                    final on = rowFromBottom < (data.progress * 6).round();
                    return Expanded(
                      child: Icon(Icons.change_history_rounded, size: 12, color: on ? _accent : HunterTheme.border),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('FROSTFALL TRIAL', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 6),
                    Text('${data.todaySteps} / ${data.goal} steps',
                        style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(data.isComplete ? 'Trial cleared.' : 'Trial ongoing.',
                        style: TextStyle(color: data.isComplete ? HunterTheme.success : HunterTheme.textSecondary, fontSize: 11.5)),
                  ],
                ),
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
      children: data.stats
          .map((s) => Expanded(child: _diamondBadge(s.icon, s.value, s.label, s.color ?? _accent)))
          .toList(),
    );
  }

  Widget _diamondBadge(IconData icon, String value, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(0.14), border: Border.all(color: color)),
              child: Transform.rotate(angle: -0.785398, child: Icon(icon, color: color, size: 18)),
            ),
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: HunterTheme.textTertiary, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  @override
  Widget water(WaterSectionData data) {
    return ClipPath(
      clipper: _FacetClipper(cut: 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: _accent.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.ac_unit_rounded, color: _accent, size: 16),
              const SizedBox(width: 8),
              Text('MELTWATER', style: TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              const Spacer(),
              Text('${data.waterIntakeMl}/${data.waterGoalMl}ml', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 11)),
            ]),
            const SizedBox(height: 10),
            Row(
              children: List.generate(10, (i) {
                final on = i < (data.progress * 10).round();
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Icon(Icons.change_history_rounded, size: 14, color: on ? _accent : HunterTheme.border),
                  ),
                );
              }),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _facetBtn(Icons.remove, data.onRemove),
              const SizedBox(width: 18),
              Text('${data.selectedCupSize}ml', style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(width: 18),
              _facetBtn(Icons.add, data.onAdd),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _facetBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: ClipPath(
        clipper: _FacetClipper(cut: 8),
        child: Container(width: 32, height: 32, color: _accent.withOpacity(0.16), child: Icon(icon, size: 16, color: _accent)),
      ),
    );
  }

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Row(children: [
      Expanded(child: _hexTile(data.nutrition)),
      const SizedBox(width: 10),
      Expanded(child: _hexTile(data.map)),
    ]);
  }

  Widget _hexTile(QuickActionItem item) {
    final color = item.isLocked ? HunterTheme.textTertiary : _accent;
    return GestureDetector(
      onTap: item.onTap,
      child: ClipPath(
        clipper: _FacetClipper(cut: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(color: HunterTheme.cardColor, border: Border.all(color: color.withOpacity(0.5))),
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

/// Angular facet clip: cuts one top corner at 45° — the shared silhouette
/// signature for every Frostborn panel.
class _FacetClipper extends CustomClipper<Path> {
  _FacetClipper({this.cut = 22});
  final double cut;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(cut, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, cut)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

Color get _accent => MembershipTheme.current.accent;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/skin_aware_surface.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';

/// Shadow Monarch — "System Window" identity.
///
/// Structural signature (distinct from Basic/Pro/Max AND from every other
/// skin): avatar sits in a squared, notch-cornered frame on the LEFT edge
/// of the hero (never floating/centered like Pro/Max); XP is shown as a
/// SEGMENTED meter of discrete blocks (a "status window" readout) instead
/// of a smooth linear bar or circular ring; the stat summary is a VERTICAL
/// list of rows (not a horizontal chip row or a grid); quests read as a
/// vertical "contract" card with tally marks instead of a progress bar;
/// quick actions stack as two full-width command rows instead of two
/// square tiles. Every color reference below comes from [HeroSectionData
/// .accentColor] (== MembershipTheme.current.accent, threaded through by
/// the caller) or an existing HunterTheme token — nothing is hardcoded.
class ShadowMonarchDashboardSections implements DashboardSkinSections {
  const ShadowMonarchDashboardSections();

  static const int _segments = 10;

  @override
  Widget hero(HeroSectionData data) {
    final hunter = data.hunter;
    final accent = data.accentColor;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;
    final filled = ((hunter.xp / 500) * _segments).round().clamp(0, _segments);

    return SkinAwareSurface(
      borderRadius: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: accent.withOpacity(0.4), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notch-cornered avatar frame — left edge, not floating/centered.
            ClipPath(
              clipper: _NotchedSquareClipper(),
              child: Container(
                width: 72,
                height: 72,
                color: accent.withOpacity(0.14),
                padding: const EdgeInsets.all(2),
                child: ClipPath(
                  clipper: _NotchedSquareClipper(),
                  child: avatarBytes != null
                      ? Image.memory(avatarBytes, fit: BoxFit.cover)
                      : Container(
                          color: HunterTheme.cardColor,
                          child: Icon(Icons.person, color: accent, size: 34),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: accent.withOpacity(0.5)),
                    ),
                    child: Text(
                      data.rankTitle.toUpperCase(),
                      style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(hunter.hunterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HunterTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
                  Text('LEVEL ${hunter.level}',
                      style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  // Segmented "status window" XP meter — discrete blocks.
                  Row(
                    children: List.generate(_segments, (i) {
                      final on = i < filled;
                      return Expanded(
                        child: Container(
                          height: 8,
                          margin: const EdgeInsets.only(right: 2),
                          color: on ? accent : HunterTheme.border,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text('${hunter.xp} / 500 XP', style: TextStyle(color: HunterTheme.textTertiary, fontSize: 10)),
                ],
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
      borderRadius: 4,
      child: _QuestCard(data: data),
    );
  }

  @override
  Widget stats(StatsSectionData data) => _StatsList(data: data);

  @override
  Widget water(WaterSectionData data) => _WaterCard(data: data);

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Column(
      children: [
        _CommandRow(item: data.nutrition),
        const SizedBox(height: 8),
        _CommandRow(item: data.map),
      ],
    );
  }
}

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.data});
  final QuestSectionData data;

  @override
  Widget build(BuildContext context) {
    // No per-section accent is threaded through the shared contracts for
    // quest/stats/water/quickActions (only HeroSectionData carries
    // `accentColor`), so these widgets read the same MembershipTheme token
    // directly — identical color source, just accessed without needing an
    // extra field on every contract.
    final accent = _accent;
    const tally = 12;
    final filledTally = (data.progress * tally).round().clamp(0, tally);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.menu_book_rounded, color: accent, size: 16),
            const SizedBox(width: 8),
            Text('DAILY CONTRACT', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
          ]),
          const SizedBox(height: 10),
          Text('${data.todaySteps} / ${data.goal} steps',
              style: TextStyle(color: HunterTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: List.generate(tally, (i) {
              final on = i < filledTally;
              return Container(width: 4, height: 16, color: on ? accent : HunterTheme.border);
            }),
          ),
          const SizedBox(height: 8),
          Text(
            data.isComplete ? 'Contract fulfilled.' : 'Contract in progress.',
            style: TextStyle(color: data.isComplete ? HunterTheme.success : HunterTheme.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatsList extends StatelessWidget {
  const _StatsList({required this.data});
  final StatsSectionData data;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Column(
        children: List.generate(data.stats.length, (i) {
          final s = data.stats[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: i == data.stats.length - 1 ? BorderSide.none : BorderSide(color: accent.withOpacity(0.15)),
              ),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: s.color ?? accent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.label.toUpperCase(),
                      style: TextStyle(color: HunterTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ),
                Text(s.value, style: TextStyle(color: HunterTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.data});
  final WaterSectionData data;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HunterTheme.cardColor,
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vertical rune-column gauge — fills bottom-up, not a horizontal bar.
          SizedBox(
            width: 28,
            height: 90,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: data.progress,
                  child: Container(color: accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HYDRATION SEAL', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                const SizedBox(height: 6),
                Text('${data.waterIntakeMl} / ${data.waterGoalMl} ml',
                    style: TextStyle(color: HunterTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Row(children: [
                  _squareBtn(Icons.remove, data.onRemove, accent),
                  const SizedBox(width: 10),
                  Text('${data.selectedCupSize} ml', style: TextStyle(color: HunterTheme.textSecondary, fontSize: 12)),
                  const SizedBox(width: 10),
                  _squareBtn(Icons.add, data.onAdd, accent),
                  const Spacer(),
                  GestureDetector(onTap: data.onEditGoal, child: Icon(Icons.edit_rounded, size: 14, color: accent)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _squareBtn(IconData icon, VoidCallback onTap, Color accent) {
    return GestureDetector(
      onTap: onTap,
      child: Container(width: 26, height: 26, color: accent.withOpacity(0.14), child: Icon(icon, size: 14, color: accent)),
    );
  }
}

class _CommandRow extends StatelessWidget {
  const _CommandRow({required this.item});
  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final color = item.isLocked ? HunterTheme.textTertiary : accent;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: HunterTheme.cardColor,
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Icon(item.icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(item.label.toUpperCase(),
                style: TextStyle(color: HunterTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const Spacer(),
            Icon(item.isLocked ? Icons.lock_outline : Icons.chevron_right_rounded, size: item.isLocked ? 14 : 18, color: color),
          ],
        ),
      ),
    );
  }
}

/// Squared corner-notch clipper for the Shadow Monarch avatar frame.
class _NotchedSquareClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    const notch = 10.0;
    return Path()
      ..moveTo(notch, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - notch)
      ..lineTo(size.width - notch, size.height)
      ..lineTo(0, size.height)
      ..lineTo(0, notch)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Shared color source for the non-hero sections in this file (hero already
/// receives `data.accentColor` directly on its contract). Always resolves
/// the LIVE `MembershipTheme.current` token (a plain static getter — no
/// BuildContext needed) so a Premium Theme switch repaints these too.
Color get _accent => MembershipTheme.current.accent;

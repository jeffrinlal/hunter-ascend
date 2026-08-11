import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';

/// Shadow Monarch — dark-fantasy / cinematic RPG identity.
///
/// ## Design intent (ground-up redesign)
/// A Skin is NOT a Premium Theme — Premium Themes already own general app
/// color/styling, and a Skin and a Premium Theme are mutually exclusive as
/// the active appearance (see `SkinService.skinAppearanceActiveNotifier`).
/// Because of that mutual exclusivity, Shadow Monarch owns its own fixed
/// dark-fantasy palette (near-black backdrop, deep/royal violet, silver
/// text) below — deliberately independent of `HunterTheme`/
/// `MembershipTheme` and of the device's light/dark mode toggle, so this
/// skin always looks like Shadow Monarch, never like "the dashboard with a
/// purple tint." This is what gives it (and the other 3 skins, redesigned
/// separately) a genuinely distinct visual identity rather than a recolor
/// of the same components.
///
/// ## Composition signature (distinct from every tier AND every other skin)
/// - Hero: asymmetric-cut cinematic banner with ambient violet glow,
///   a circular avatar medallion with a breathing glow ring, a rank
///   sigil pill, and a gradient "mana bar" XP presentation with a moving
///   sheen highlight.
/// - Quest: a "Trial Ledger" card — big numeral readout + a gradient
///   progress rail, asymmetric corner cut.
/// - Stats: a "War Ledger" — a vertical list of sigil-badged rows.
/// - Water: a "Hydration Sigil" — a vertical vessel gauge beside a
///   compact readout + rune buttons.
/// - Quick Actions: two "Command Seal" rows with a tap ripple.
///
/// ## Layout safety
/// Every text element that can vary in length (hunter name, level, rank
/// title, stat values, step/water counts) is bounded with `Flexible`/
/// `Expanded`/`FittedBox` + `TextOverflow.ellipsis` — nothing here uses
/// fixed pixel widths or `Positioned` for dynamic content, so this renders
/// correctly for any hunter name, any XP/level/stat value, and on both
/// small and large phone screens without overflow or clipping.
class ShadowMonarchDashboardSections implements DashboardSkinSections {
  const ShadowMonarchDashboardSections();

  @override
  Widget hero(HeroSectionData data) => _MonarchHero(data: data);

  @override
  Widget quest(QuestSectionData data) => _MonarchQuestCard(data: data);

  @override
  Widget stats(StatsSectionData data) => _MonarchStatsList(data: data);

  @override
  Widget water(WaterSectionData data) => _MonarchWaterCard(data: data);

  @override
  Widget quickActions(QuickActionsSectionData data) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonarchCommandRow(item: data.nutrition),
        const SizedBox(height: 10),
        _MonarchCommandRow(item: data.map),
      ],
    );
  }
}

// ── Shadow Monarch palette ──────────────────────────────────────────────
//
// Skin-owned constants, intentionally independent of HunterTheme /
// MembershipTheme (see class doc above). Not a second theme system — just
// this one skin's own fixed identity colors, scoped to this file.
class _Ink {
  _Ink._();

  static const Color bgTop = Color(0xFF150E22);
  static const Color bgBottom = Color(0xFF07050C);
  static const Color panel = Color(0xFF17101F);
  static const Color panelAlt = Color(0xFF130C1A);
  static const Color line = Color(0xFF2C2140);

  static const Color violet = Color(0xFF7C4DFF);
  static const Color violetDeep = Color(0xFF3E2470);
  static const Color violetGlow = Color(0xFFA57BFF);

  static const Color silver = Color(0xFFEFEAF6);
  static const Color silverDim = Color(0xFFB3A8CB);
  static const Color silverFaint = Color(0xFF756A90);

  static const Color gold = Color(0xFFE7C878);
}

// ── Hero ─────────────────────────────────────────────────────────────────

class _MonarchHero extends StatefulWidget {
  const _MonarchHero({required this.data});
  final HeroSectionData data;

  @override
  State<_MonarchHero> createState() => _MonarchHeroState();
}

class _MonarchHeroState extends State<_MonarchHero> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hunter = widget.data.hunter;
    final avatarBytes = (hunter.profilePicture?.isNotEmpty ?? false)
        ? base64Decode(hunter.profilePicture!)
        : null;
    final xpProgress = (hunter.xp / 500).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(12),
        bottomRight: Radius.circular(30),
        bottomLeft: Radius.circular(12),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_Ink.bgTop, _Ink.bgBottom],
          ),
        ),
        child: Stack(
          children: [
            // Ambient violet glow blobs — purely decorative, drawn behind
            // the content layer below, never affects layout or overlaps
            // text (it fills the panel's own bounds only).
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => CustomPaint(painter: _MonarchGlowPainter(t: _glow.value)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MonarchAvatar(avatarBytes: avatarBytes, glow: _glow),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _RankSigil(text: widget.data.rankTitle),
                        const SizedBox(height: 12),
                        Text(
                          hunter.hunterName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _Ink.silver,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'LV',
                              style: TextStyle(color: _Ink.silverFaint, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${hunter.level}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _Ink.violetGlow, fontSize: 15, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MonarchXpBar(progress: xpProgress, sheen: _glow),
                        const SizedBox(height: 7),
                        Text(
                          '${hunter.xp} / 500 XP',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _Ink.silverFaint, fontSize: 10.5, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                        ),
                      ],
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
}

class _MonarchAvatar extends StatelessWidget {
  const _MonarchAvatar({required this.avatarBytes, required this.glow});
  final Uint8List? avatarBytes;
  final Animation<double> glow;

  static const double _size = 68;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final g = glow.value;
        return Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: _Ink.violetGlow.withOpacity(0.26 + 0.16 * g), blurRadius: 20, spreadRadius: 1),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [_Ink.violetDeep, _Ink.violet]),
              border: Border.all(color: _Ink.violetGlow.withOpacity(0.55), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Container(
                color: _Ink.panel,
                child: avatarBytes != null
                    ? Image.memory(avatarBytes!, fit: BoxFit.cover, width: _size, height: _size)
                    : const Center(child: Icon(Icons.person_rounded, color: _Ink.silverDim, size: 30)),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RankSigil extends StatelessWidget {
  const _RankSigil({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _Ink.violetDeep.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Ink.violet.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.diamond_rounded, size: 10, color: _Ink.violetGlow),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _Ink.silverDim, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient "mana bar" XP presentation with a soft moving sheen — replaces
/// the old discrete-block "status window" meter with a smoother, more
/// premium-feeling continuous bar.
class _MonarchXpBar extends StatelessWidget {
  const _MonarchXpBar({required this.progress, required this.sheen});
  final double progress;
  final Animation<double> sheen;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: SizedBox(
        height: 10,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: _Ink.line),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [_Ink.violetDeep, _Ink.violetGlow]),
                  ),
                ),
              ),
            ),
            // Sheen highlight — a soft translucent band sweeping left to
            // right, clipped to the bar's own bounds so it can never
            // overflow or affect layout.
            AnimatedBuilder(
              animation: sheen,
              builder: (context, _) => Align(
                alignment: Alignment(-1 + 2 * sheen.value, 0),
                child: FractionallySizedBox(
                  widthFactor: 0.22,
                  heightFactor: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white.withOpacity(0), Colors.white.withOpacity(0.16), Colors.white.withOpacity(0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft ambient violet glow blobs behind the hero content. Uses blurred
/// circles rather than any hard shape — purely atmospheric, never carries
/// text, so it can never overlap or clip dynamic content.
class _MonarchGlowPainter extends CustomPainter {
  _MonarchGlowPainter({required this.t});
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    final p1 = Paint()
      ..color = _Ink.violet.withOpacity(0.14 + 0.08 * wave)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.1), size.shortestSide * 0.6, p1);

    final p2 = Paint()
      ..color = _Ink.violetDeep.withOpacity(0.14 + 0.06 * (1 - wave))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 1.05), size.shortestSide * 0.55, p2);
  }

  @override
  bool shouldRepaint(covariant _MonarchGlowPainter oldDelegate) => oldDelegate.t != t;
}

// ── Quest ("Trial Ledger") ────────────────────────────────────────────────

class _MonarchQuestCard extends StatelessWidget {
  const _MonarchQuestCard({required this.data});
  final QuestSectionData data;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(26),
        bottomRight: Radius.circular(12),
        bottomLeft: Radius.circular(26),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        color: _Ink.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, color: _Ink.violetGlow, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'TRIAL LEDGER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Ink.silverDim, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6),
                  ),
                ),
                const Spacer(),
                if (data.isComplete) _completeBadge(),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    '${data.todaySteps}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Ink.silver, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '/ ${data.goal} steps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Ink.silverFaint, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                width: double.infinity,
                child: Stack(
                  children: [
                    Container(color: _Ink.line),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data.progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_Ink.violetDeep, _Ink.violetGlow]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              data.isComplete ? 'Trial fulfilled — the shadows take notice.' : 'Trial in progress...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: data.isComplete ? _Ink.gold : _Ink.silverFaint,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _completeBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _Ink.gold.withOpacity(0.16),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _Ink.gold.withOpacity(0.55)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_rounded, size: 11, color: _Ink.gold),
        const SizedBox(width: 3),
        const Text('DONE', style: TextStyle(color: _Ink.gold, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1)),
      ],
    ),
  );
}

// ── Stats ("War Ledger") ───────────────────────────────────────────────────

class _MonarchStatsList extends StatelessWidget {
  const _MonarchStatsList({required this.data});
  final StatsSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Ink.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Ink.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(data.stats.length, (i) {
          final s = data.stats[i];
          final isLast = i == data.stats.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: isLast ? BorderSide.none : BorderSide(color: _Ink.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _Ink.violetDeep.withOpacity(0.4),
                    border: Border.all(color: _Ink.violet.withOpacity(0.5)),
                  ),
                  child: Icon(s.icon, color: _Ink.violetGlow, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _Ink.silverDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      s.value,
                      maxLines: 1,
                      style: const TextStyle(color: _Ink.silver, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── Water ("Hydration Sigil") ──────────────────────────────────────────────

class _MonarchWaterCard extends StatelessWidget {
  const _MonarchWaterCard({required this.data});
  final WaterSectionData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _Ink.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _Ink.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 28,
              height: 84,
              color: _Ink.line.withOpacity(0.6),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: data.progress),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => FractionallySizedBox(
                    heightFactor: v,
                    widthFactor: 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [_Ink.violetGlow, _Ink.violetDeep],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.water_drop_rounded, color: _Ink.violetGlow, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'HYDRATION SIGIL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _Ink.silverDim, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  '${data.waterIntakeMl} / ${data.waterGoalMl} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _Ink.silver, fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    _RuneButton(icon: Icons.remove_rounded, onTap: data.onRemove),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '${data.selectedCupSize} ml',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _Ink.silverDim, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RuneButton(icon: Icons.add_rounded, onTap: data.onAdd),
                    const Spacer(),
                    GestureDetector(
                      onTap: data.onEditGoal,
                      child: const Icon(Icons.tune_rounded, size: 16, color: _Ink.violetGlow),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RuneButton extends StatelessWidget {
  const _RuneButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _Ink.violetDeep.withOpacity(0.4),
          border: Border.all(color: _Ink.violet.withOpacity(0.5)),
        ),
        child: Icon(icon, size: 16, color: _Ink.violetGlow),
      ),
    );
  }
}

// ── Quick Actions ("Command Seals") ───────────────────────────────────────

class _MonarchCommandRow extends StatelessWidget {
  const _MonarchCommandRow({required this.item});
  final QuickActionItem item;

  @override
  Widget build(BuildContext context) {
    final locked = item.isLocked;
    final fg = locked ? _Ink.silverFaint : _Ink.silver;
    final iconColor = locked ? _Ink.silverFaint : _Ink.violetGlow;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _Ink.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: locked ? _Ink.line : _Ink.violet.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (locked ? _Ink.line : _Ink.violetDeep).withOpacity(0.55),
                ),
                child: Icon(item.icon, color: iconColor, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, size: 16, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

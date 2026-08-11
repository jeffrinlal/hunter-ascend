import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/skins/dashboard/dashboard_section_contracts.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_dashboard_sections.dart';
import 'package:hunter_ascend/core/skins/dashboard/skin_tone.dart';

/// Shadow Monarch — dark-fantasy / cinematic RPG identity.
///
/// ## Architecture rule this file follows
/// - **SKIN** owns: UI structure, component design, layout composition,
///   information hierarchy, animation and decorative language.
/// - **PREMIUM THEME** owns: colors.
///
/// Accordingly, this file contains **no hardcoded color values at all**.
/// Every color is resolved through the shared [SkinTone] mapping (the same
/// one used by every other skin), which forwards to the existing
/// `HunterTheme` tokens and therefore to the active Premium Theme. [SkinTone]
/// is *not* a second theme system — it introduces no new colors and stores no
/// state; it only gives the skins' structural roles readable names that point
/// at existing tokens.
///
/// Net effect:
/// - Shadow Monarch + any Premium Theme → same Shadow Monarch structure,
///   that theme's colors.
/// - Classic (no skin active) → completely unaffected; the resolver never
///   builds this file's widgets (see `skin_dashboard_sections.dart`).
///
/// ## Composition signature (distinct from every tier AND every other skin)
/// - Hero: asymmetric-cut cinematic banner with ambient animated glow, a
///   circular avatar medallion with a breathing glow ring, a rank sigil
///   pill, and a gradient XP rail with a moving sheen highlight.
/// - Quest: "Trial Ledger" — asymmetric-cut card, large numeral readout,
///   gradient progress rail, completion badge.
/// - Stats: "War Ledger" — vertical list of sigil-badged rows.
/// - Water: "Hydration Sigil" — vertical vessel gauge + compact readout
///   with rune buttons.
/// - Quick Actions: two "Command Seal" rows with ink ripple feedback.
///
/// ## Layout safety
/// Every variable-length value (hunter name, level, rank title, stat values,
/// step/water counts) is bounded with `Flexible`/`Expanded`/`FittedBox` plus
/// `TextOverflow.ellipsis`. No `Positioned` widget carries dynamic content,
/// no hardcoded text widths, no fixed heights around variable text — so this
/// renders correctly for any hunter name, any XP/level/stat value, and on
/// both small and large phone screens without overflow or clipping.
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
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [SkinTone.backdropTop, SkinTone.backdropBottom],
          ),
        ),
        child: Stack(
          children: [
            // Ambient accent glow — purely decorative, painted behind the
            // content layer and clipped to this panel's own bounds, so it
            // can never overlap or clip dynamic text.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _glow,
                builder: (context, _) => CustomPaint(
                  painter: _MonarchGlowPainter(
                    t: _glow.value,
                    accent: SkinTone.accent,
                    accentBright: SkinTone.accentBright,
                    glowStrength: SkinTone.glow,
                  ),
                ),
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
                          style: TextStyle(
                            color: SkinTone.textStrong,
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
                            Text(
                              'LV',
                              style: TextStyle(
                                color: SkinTone.textFaint,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${hunter.level}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: SkinTone.accentBright,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                ),
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
                          style: TextStyle(
                            color: SkinTone.textFaint,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
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
              BoxShadow(
                color: SkinTone.accentBright.withOpacity((0.26 + 0.16 * g) * SkinTone.glow),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          padding: const EdgeInsets.all(2.5),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: SkinTone.accentRamp),
              border: Border.all(color: SkinTone.accentBright.withOpacity(0.55), width: 1),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(
              child: Container(
                color: SkinTone.panel,
                child: avatarBytes != null
                    ? Image.memory(avatarBytes!, fit: BoxFit.cover, width: _size, height: _size)
                    : Center(child: Icon(Icons.person_rounded, color: SkinTone.textSoft, size: 30)),
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
        color: SkinTone.accent.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkinTone.accent.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.diamond_rounded, size: 10, color: SkinTone.accentBright),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: SkinTone.textSoft,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient XP rail with a soft moving sheen — the skin's signature XP
/// presentation (continuous rail + highlight sweep), colored entirely by the
/// active Premium Theme's accent ramp.
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
            Container(color: SkinTone.line),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: SkinTone.accentRamp),
                  ),
                ),
              ),
            ),
            // Sheen highlight — clipped to the rail's own bounds, so it can
            // never overflow or affect layout.
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
                        colors: [
                          SkinTone.textStrong.withOpacity(0),
                          SkinTone.textStrong.withOpacity(0.16),
                          SkinTone.textStrong.withOpacity(0),
                        ],
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

/// Soft ambient accent glow behind the hero content. Blurred circles only —
/// purely atmospheric, carries no text, cannot overlap or clip content.
class _MonarchGlowPainter extends CustomPainter {
  _MonarchGlowPainter({
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
    final wave = 0.5 + 0.5 * math.sin(t * 2 * math.pi);

    final p1 = Paint()
      ..color = accentBright.withOpacity(((0.14 + 0.08 * wave) * glowStrength).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 46);
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.1), size.shortestSide * 0.6, p1);

    final p2 = Paint()
      ..color = accent.withOpacity(((0.14 + 0.06 * (1 - wave)) * glowStrength).clamp(0.0, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 52);
    canvas.drawCircle(Offset(size.width * 0.05, size.height * 1.05), size.shortestSide * 0.55, p2);
  }

  @override
  bool shouldRepaint(covariant _MonarchGlowPainter oldDelegate) =>
      oldDelegate.t != t ||
      oldDelegate.accent != accent ||
      oldDelegate.accentBright != accentBright ||
      oldDelegate.glowStrength != glowStrength;
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
        color: SkinTone.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_stories_rounded, color: SkinTone.accentBright, size: 16),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'TRIAL LEDGER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SkinTone.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                const Spacer(),
                if (data.isComplete) const _CompleteBadge(),
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
                    style: TextStyle(color: SkinTone.textStrong, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '/ ${data.goal} steps',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: SkinTone.textFaint, fontSize: 12, fontWeight: FontWeight.w600),
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
                    Container(color: SkinTone.line),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: data.progress),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        widthFactor: v,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: SkinTone.accentRamp),
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
                color: data.isComplete ? SkinTone.complete : SkinTone.textFaint,
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

class _CompleteBadge extends StatelessWidget {
  const _CompleteBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SkinTone.complete.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkinTone.complete.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 11, color: SkinTone.complete),
          const SizedBox(width: 3),
          Text(
            'DONE',
            style: TextStyle(
              color: SkinTone.complete,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
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
        color: SkinTone.panelAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SkinTone.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(data.stats.length, (i) {
          final s = data.stats[i];
          final isLast = i == data.stats.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              border: Border(bottom: isLast ? BorderSide.none : BorderSide(color: SkinTone.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: SkinTone.accent.withOpacity(0.14),
                    border: Border.all(color: SkinTone.accent.withOpacity(0.5)),
                  ),
                  // Per-stat icon tint still honors the caller-supplied stat
                  // color when present (an existing theme token passed in by
                  // the tier layout), else falls back to the theme accent.
                  child: Icon(s.icon, color: s.color ?? SkinTone.accentBright, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: SkinTone.textSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
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
                      style: TextStyle(color: SkinTone.textStrong, fontSize: 15, fontWeight: FontWeight.w800),
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
        color: SkinTone.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SkinTone.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 28,
              height: 84,
              color: SkinTone.line.withOpacity(0.6),
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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: SkinTone.accentRamp,
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
                    Icon(Icons.water_drop_rounded, color: SkinTone.accentBright, size: 14),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'HYDRATION SIGIL',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: SkinTone.textSoft,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Text(
                  '${data.waterIntakeMl} / ${data.waterGoalMl} ml',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: SkinTone.textStrong, fontSize: 16, fontWeight: FontWeight.w800),
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
                        style: TextStyle(color: SkinTone.textSoft, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RuneButton(icon: Icons.add_rounded, onTap: data.onAdd),
                    const Spacer(),
                    GestureDetector(
                      onTap: data.onEditGoal,
                      child: Icon(Icons.tune_rounded, size: 16, color: SkinTone.accentBright),
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
          color: SkinTone.accent.withOpacity(0.14),
          border: Border.all(color: SkinTone.accent.withOpacity(0.5)),
        ),
        child: Icon(icon, size: 16, color: SkinTone.accentBright),
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
    final fg = locked ? SkinTone.textFaint : SkinTone.textStrong;
    final iconColor = locked ? SkinTone.textFaint : SkinTone.accentBright;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: SkinTone.panel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: locked ? SkinTone.line : SkinTone.accent.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (locked ? SkinTone.line : SkinTone.accent).withOpacity(0.18),
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

import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/core/theme/membership_theme.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';

/// Large premium game-mode card for the Battle Hub.
///
/// Pure presentation: renders the emoji medallion, title, description, mode
/// tag and ENTER button. All behavior (navigation, Coming Soon dialogs) is
/// injected via [onEnter]; all theming is delegated to the membership
/// widgets, so the card automatically re-skins per tier without duplicating
/// any theme code.
///
/// Set [comingSoon] for modes that are not implemented yet — the card adds
/// a discreet SOON chip and an hourglass on the ENTER button. Callers
/// typically wire [onEnter] to the hub's Coming Soon dialog for those.
class BattleModeCard extends StatelessWidget {
  const BattleModeCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.tag,
    required this.onEnter,
    this.comingSoon = false,
    this.incoming = false,
  });

  final String emoji;
  final String title;
  final String description;

  /// Small mode chip (e.g. "PvP" / "PvE").
  final String tag;
  final VoidCallback onEnter;
  final bool comingSoon;

  /// When true, the card renders with a danger-accent highlight (red border,
  /// subtle glow, "NEW" chip) indicating an incoming request/challenge the
  /// user should act on. Used for incoming Duel, Rival, and Step Clash cards.
  final bool incoming;

  @override
  Widget build(BuildContext context) {
    final accent = MembershipTheme.current.accent;

    return MembershipCard(
      padding: const EdgeInsets.all(20),
      borderColor: incoming ? HunterTheme.danger : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Incoming highlight glow bar ──
          if (incoming)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: HunterTheme.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: HunterTheme.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: HunterTheme.danger,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: HunterTheme.danger.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'NEW CHALLENGE',
                    style: TextStyle(
                      color: HunterTheme.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji medallion.
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.22),
                      accent.withOpacity(0.08),
                    ],
                  ),
                  border: Border.all(color: accent.withOpacity(0.4), width: 1.4),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.25 * HunterTheme.glowStrength),
                      blurRadius: 18,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: HunterTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: HunterTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  _ModeTag(label: tag),
                  if (comingSoon) ...[
                    const SizedBox(height: 6),
                    const _ModeTag(label: 'SOON', muted: true),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          MembershipButton.primary(
            incoming ? 'VIEW REQUEST' : 'ENTER',
            onTap: onEnter,
            expanded: true,
            icon: comingSoon
                ? Icons.hourglass_top_rounded
                : incoming
                    ? Icons.notifications_active_rounded
                    : Icons.arrow_forward_rounded,
          ),
        ],
      ),
    );
  }
}

/// Compact disabled "coming soon" mode tile for the Battle Hub's upcoming
/// modes section (Weekly Raids, Guild Battles, World Boss, ...).
///
/// Deliberately non-interactive ([IgnorePointer]) and dimmed, but still
/// premium-looking via [MembershipCard] — future modes simply swap this for
/// a live [BattleModeCard] when they ship.
class BattleHubTeaserCard extends StatelessWidget {
  const BattleHubTeaserCard({
    super.key,
    required this.emoji,
    required this.title,
  });

  final String emoji;
  final String title;

  @override
  Widget build(BuildContext context) {
    final accent = MembershipTheme.current.accent;

    return IgnorePointer(
      child: Opacity(
        opacity: 0.62,
        child: MembershipCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.18),
                      accent.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(color: accent.withOpacity(0.3)),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 17)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: HunterTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const _ModeTag(label: 'COMING SOON', muted: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded tag chip (mode label / coming-soon marker), tinted with the
/// tier accent — or a neutral muted tone for disabled states.
class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color =
        muted ? HunterTheme.textTertiary : MembershipTheme.current.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

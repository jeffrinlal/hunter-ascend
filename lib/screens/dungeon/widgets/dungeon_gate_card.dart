import 'package:flutter/material.dart';
import 'package:hunter_ascend/core/theme/hunter_theme.dart';
import 'package:hunter_ascend/services/rank_service.dart';
import 'package:hunter_ascend/widgets/membership/membership_button.dart';
import 'package:hunter_ascend/widgets/membership/membership_card.dart';

/// Unlock state of a dungeon gate — presentation only.
///
/// The button is live only when the lobby passes an [DungeonGateCard.onEnter]
/// callback; every other combination renders it disabled. [clearedToday] is
/// the daily-dungeon "rewards claimed" state (Phase 5); [higherRank] is the
/// Phase 6 force-open candidate (temporarily unlockable with a rewarded ad).
enum DungeonGateStatus { available, locked, higherRank, clearedToday }

/// Premium gate card for the Dungeon Lobby ("Gate Selection Center").
///
/// Pure presentation: renders the rank crest (letter + canonical rank color
/// from [HunterRank.color]), gate name, difficulty, description, status
/// badge, optional unlock hint and the action button. All behavior is
/// injected via [onEnter]; all card/button theming is delegated to the
/// membership widgets so the gate re-skins per tier with no duplicated
/// theme code.
class DungeonGateCard extends StatelessWidget {
  const DungeonGateCard({
    super.key,
    required this.rank,
    required this.difficulty,
    required this.description,
    required this.status,
    required this.buttonLabel,
    this.onEnter,
    this.lockReason,
    this.forceOpen = false,
  });

  /// The rank this gate is keyed on — letter, label and color all come from
  /// the centralized [RankService] ladder (no second ranking system).
  final HunterRank rank;
  final String difficulty;
  final String description;
  final DungeonGateStatus status;

  /// Action button label ("ENTER GATE" for open gates, "LOCKED" etc. for
  /// closed ones).
  final String buttonLabel;

  /// Button tap handler — `null` renders the button disabled (the card's
  /// single source of truth for tappability).
  final VoidCallback? onEnter;

  /// Short hint shown under the description for closed gates
  /// (e.g. "Reach D Rank Hunter").
  final String? lockReason;

  /// Phase 6 force-open presentation: renders the ⚠ FORCE OPEN notice and
  /// the Hunter Association stabilization copy under the description.
  final bool forceOpen;

  bool get _isOpen => onEnter != null;

  @override
  Widget build(BuildContext context) {
    final rankColor = rank.color;

    return Opacity(
      opacity: _isOpen ? 1.0 : 0.72,
      child: MembershipCard(
        padding: const EdgeInsets.all(20),
        borderColor: _isOpen ? rankColor.withOpacity(0.45) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Rank crest.
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        rankColor.withOpacity(_isOpen ? 0.28 : 0.14),
                        rankColor.withOpacity(_isOpen ? 0.10 : 0.05),
                      ],
                    ),
                    border: Border.all(
                      color: rankColor.withOpacity(_isOpen ? 0.55 : 0.3),
                      width: 1.4,
                    ),
                    boxShadow: [
                      if (_isOpen)
                        BoxShadow(
                          color: rankColor.withOpacity(
                            0.3 * HunterTheme.glowStrength,
                          ),
                          blurRadius: 18,
                        ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    rank.letter,
                    style: TextStyle(
                      color: rankColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${rank.label} Gate',
                        style: TextStyle(
                          color: HunterTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        difficulty,
                        style: TextStyle(
                          color: rankColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: TextStyle(
                          color: HunterTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                      if (forceOpen) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 14,
                              color: HunterTheme.gold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'FORCE OPEN',
                              style: TextStyle(
                                color: HunterTheme.gold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'The Hunter Association can temporarily '
                          'stabilize this gate.',
                          style: TextStyle(
                            color: HunterTheme.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ] else if (lockReason != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          lockReason!,
                          style: TextStyle(
                            color: HunterTheme.textTertiary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _GateStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 16),
            // Disabled gates pass onTap: null — MembershipButton already
            // renders the untouched stock look when not tappable.
            Opacity(
              opacity: _isOpen ? 1.0 : 0.55,
              child: IgnorePointer(
                ignoring: !_isOpen,
                child: MembershipButton.primary(
                  buttonLabel,
                  onTap: _isOpen ? onEnter : null,
                  expanded: true,
                  icon: _isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded status badge (AVAILABLE / LOCKED / FORCE OPEN / CLEARED).
class _GateStatusBadge extends StatelessWidget {
  const _GateStatusBadge({required this.status});

  final DungeonGateStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      DungeonGateStatus.available =>
        ('AVAILABLE', HunterTheme.success),
      DungeonGateStatus.locked =>
        ('LOCKED', HunterTheme.textTertiary),
      DungeonGateStatus.higherRank =>
        ('FORCE OPEN', HunterTheme.gold),
      DungeonGateStatus.clearedToday =>
        ('CLEARED', HunterTheme.gold),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
